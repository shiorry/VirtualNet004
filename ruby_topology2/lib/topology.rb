# -*- coding: utf-8 -*-
require 'forwardable'
require 'link'
require 'host'
require 'observer'
require 'trema-extensions/port'

#
# Topology information containing the list of known switches, ports,
# and links.
#
class Topology
  include Observable
  extend Forwardable

  def_delegator :@ports, :each_pair, :each_switch
  def_delegator :@links, :each, :each_link
  def_delegator :@hosts, :each, :each_host

  def initialize(view)
    @ports = Hash.new { [].freeze }
    @links = []
    @hosts = []
    @slice = Array.new()
    add_observer view
    # テストスライス
    @slice[1] = []
    @slice[1].push("192.168.0.1")
    @slice[1].push("192.168.0.2")
    @slice[2] = []
    @slice[2].push("192.168.0.3")
    @slice[2].push("192.168.0.4")
  end

  def delete_switch(dpid)
    @ports[dpid].each do | each |
      delete_port dpid, each
    end
    @ports.delete dpid
  end

  def update_port(dpid, port)
    if port.down?
      delete_port dpid, port
    elsif port.up?
      add_port dpid, port
    end
  end

  def add_port(dpid, port)
    @ports[dpid] += [port]
  end

  def delete_port(dpid, port)
    @ports[dpid] -= [port]
    delete_link_by dpid, port
  end

  def add_link_by(dpid, packet_in)
    fail 'Not an LLDP packet!' unless packet_in.lldp?

    link = Link.new(dpid, packet_in)
    unless @links.include?(link)
      @links << link
      @links.sort!
      changed
      notify_observers self
    end
  end

  def add_host_by(dpid, packet_in)
    host = Host.new(dpid, packet_in)
    #unless @hosts.include?(host)
    unless get_host(packet_in.ipv4_saddr.to_s)
      @hosts << host
      @hosts.sort!
      changed
      notify_observers self
    end
  end
  
  # dpidからMACアドレスを取得
  def get_mac(dpid)
    result = nil
    @links.each do | each |
      if each.dpid1 == dpid
        result = each.mac1
        break
      end
    end
    return result
  end
  
  # IPアドレスからホストを取得
  def get_host(address)
    result = nil
    @hosts.each do | each |
      if each.ipaddr2.to_s == address.to_s
        result = each
        break
      end
    end
    return result
  end

  # 2つのホストが同じスライスに属していたらtrueを返す
  # num_slice : 調査対象のスライス番号。負の数を指定すれば全スライスを探索
  def isInSameSlice?(host1, host2, num_slice)
    result = false
    if num_slice<0
      @slice.each do | eachs |
        if each.nil?
          next
        elsif each.include?(host1.ipaddr2.to_s) && each.include?(host2.ipaddr2.to_s)
          result = true
        end
      end
    else
      if @slice[num_slice].include?(host1.ipaddr2.to_s) && @slice[num_slice].include?(host2.ipaddr2.to_s)
        result = true
      end
    end
    return result
  end

  private

  def delete_link_by(dpid, port)
    @links.each do | each |
      if each.has?(dpid, port.number)
        changed
        @links -= [each]
      end
    end
    notify_observers self
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
