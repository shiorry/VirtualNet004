# -*- coding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path(File.join File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'bundler/setup'

require 'command-line'
require 'topology'
require 'trema'
require 'trema-extensions/port'

#
# This controller collects network topology information using LLDP.
#
class TopologyController < Controller
  periodic_timer_event :flood_lldp_frames, 1

  def start
    @command_line = CommandLine.new
    @command_line.parse(ARGV.dup)
    @topology = Topology.new(@command_line.view)
  end

  def switch_ready(dpid)
    send_message dpid, FeaturesRequest.new
  end

  def features_reply(dpid, features_reply)
    features_reply.physical_ports.select(&:up?).each do | each |
      @topology.add_port dpid, each
    end
  end

  def switch_disconnected(dpid)
    @topology.delete_switch dpid
  end

  def port_status(dpid, port_status)
    updated_port = port_status.port
    return if updated_port.local?
    @topology.update_port dpid, updated_port
  end

  def packet_in(dpid, packet_in)
    if packet_in.lldp?
      @topology.add_link_by dpid, packet_in
    elsif packet_in.ipv4? || packet_in.icmpv4? ||packet_in.arp?
      @topology.add_host_by dpid, packet_in
      handle_ipv4 dpid, packet_in
    end
  end

  private

  def flood_lldp_frames
    @topology.each_switch do | dpid, ports |
      send_lldp dpid, ports
    end
  end

  def send_lldp(dpid, ports)
    ports.each do | each |
      port_number = each.number
      send_packet_out(
        dpid,
        actions: SendOutPort.new(port_number),
        data: lldp_binary_string(dpid, port_number)
      )
    end
  end

  def lldp_binary_string(dpid, port_number)
    destination_mac = @command_line.destination_mac
    if destination_mac
      Pio::Lldp.new(dpid: dpid,
                    port_number: port_number,
                    destination_mac: destination_mac.value).to_binary
    else
      Pio::Lldp.new(dpid: dpid, port_number: port_number).to_binary
    end
  end
  
# IPV4パケットの処理
  def handle_ipv4(dpid, message)
    if message.arp?
      source_ip = message.arp_spa
      dest_ip = message.arp_tpa
      # puts "ARP from " + source_ip.to_s + " to " + dest_ip.to_s
    else
      source_ip = message.ipv4_saddr
      dest_ip = message.ipv4_daddr
      puts "IPv4 from " + source_ip.to_s + " to " + dest_ip.to_s
    end
    dest_host = @topology.get_host(dest_ip)
    source_host = @topology.get_host(source_ip)
    if dest_host.nil? || source_host.nil?
      return
    end
    # 送受信ノードがホストの場合
    if ! @topology.isInSameSlice?(source_host, dest_host, -1)
      # 別スライスなら無視
      puts "These hosts are not in same slice."
      return
    end
    dest_dpid = dest_host.dpid1  # 宛先スイッチのdpid
    source_dpid = source_host.dpid1  # 送信元スイッチのdpid
    # flow_mod(dest_dpid, message, SendOutPort.new(dest_host.port1))
    # 次の送信先ポートをダイクストラで選ぶ
    target_dpid = source_dpid # 探索の基点
    neighbor_dpid = nil       # 隣接ノードのdpid
    dijkstra_stack = []       # 次にtarget_dpidにすべきスイッチ
    dijkstra_hops = []        # 各スイッチへの暫定ホップ数
    dijkstra_concluded = []   # 確定かどうか
    dijkstra_walk_dpid = []   # 順路１つ前のスイッチのdpid
    dijkstra_walk_port = []   # 順路１つ前のスイッチのポート
    dijkstra_hops[source_dpid] = 0
    dijkstra_concluded[source_dpid] = 1
    #puts "dijkstra : "+source_dpid
    puts "@" + dpid.to_s +  ", dijkstra : ["+source_host.to_s + "] -> [" + dest_host.to_s + "]"
    while true
      if dest_dpid==source_dpid
        break
      end
      @topology.each_link do | each |
        if each.dpid1 != target_dpid
          next
        end
        puts "search link : " + each.to_s
        neighbor_dpid = each.dpid2
        if dijkstra_concluded[neighbor_dpid] == nil && (dijkstra_hops[neighbor_dpid] == nil || dijkstra_hops[neighbor_dpid] > dijkstra_hops[target_dpid] + 1)
          dijkstra_hops[neighbor_dpid] = dijkstra_hops[target_dpid] + 1
          dijkstra_walk_dpid[neighbor_dpid] = target_dpid
          dijkstra_walk_port[neighbor_dpid] = each.port1
          dijkstra_stack.push(neighbor_dpid)
          puts "switch " + target_dpid.to_s + "(" +each.port1.to_s + ") -> switch " + neighbor_dpid.to_s + "  hop=" + dijkstra_hops[neighbor_dpid].to_s + "   ."
        end
      end
      while true
        next_dpid = dijkstra_stack.shift
        if next_dpid == nil
          break
        elsif dijkstra_concluded[next_dpid] != nil
          next
        end
        break
      end
      target_dpid = next_dpid
      if next_dpid != nil
        dijkstra_concluded[next_dpid] = 1
      end
      if target_dpid == nil || target_dpid == dest_dpid
        break
      end
    end
    if dijkstra_hops[dest_dpid] == nil
      # 宛先への経路が見つからない場合
      puts "tried dijkstra, but there is no route"
    else
      # 経路を元にフローテーブルを一挙更新
        target_dpid = dest_dpid
      while true
        if target_dpid == source_dpid
          break
        end
        puts "switch[" + dijkstra_walk_dpid[target_dpid].to_s + "] (port " + dijkstra_walk_port[target_dpid].to_s + ") -> switch[" + target_dpid.to_s + "]"
        send_flow_mod_add(
          dijkstra_walk_dpid[target_dpid],
          :match => ExactMatch.from(message),
          # :match => Match.new( :nw_dst => dest_ip.to_s, :nw_src => source_ip.to_s ),
          # :actions => SendOutPort.new(dijkstra_walk_port[target_dpid].to_i)
          :actions =># [
            # Trema::SetIpDstAddr.new(dest_ip.to_s),
            # Trema::SetEthDstAddr.new(@topology.get_mac(target_dpid)),
            Trema::SendOutPort.new(dijkstra_walk_port[target_dpid].to_i)
            #]
          )
        target_dpid = dijkstra_walk_dpid[target_dpid]
      end
      send_flow_mod_add(
        dest_dpid,
        :match => ExactMatch.from(message),
        # :match => Match.new( :nw_dst => dest_ip.to_s, :nw_src => source_ip.to_s ),
        # :actions => SendOutPort.new(dest_host.port1.to_i)
        :actions => #[
          # Trema::SetIpDstAddr.new(dest_ip.to_s),
          # Trema::SetEthDstAddr.new(dest_host.mac1),
          Trema::SendOutPort.new(dest_host.port1.to_i)
          #]
        )
	  	send_packet_out(
	  		dest_dpid, 
	  		:packet_in => message, 
	  		:actions => Trema::SendOutPort.new(dest_host.port1.to_i) )
    end
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
