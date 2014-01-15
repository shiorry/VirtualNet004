# coding: utf-8

# スイッチ
switches = Array.new
n_switches = 0
# ホスト
hosts = Array.new
hosts_ip = Array.new
hosts_subnet = Array.new
n_hosts = 0
# リンク
links = Array.new
n_links = 0
# スライス
slice_names = Array.new # スライス名
slice_hosts = Array.new # 配列を要素に持つ配列。ホストの添字を代入したい。
slice_hostname = Array.new # ホスト名
slice_hostip = Array.new   # ホストのIP
slice_hostsnm = Array.new  # ホストのサブネットマスク
n_hosts_in_slice = Array.new
n_slice = 0

# ファイルパス
fp_topology = open("top13.conf","r")
fp_slice = open("slice.txt","w")
fp_detail = open("detail.txt","w")
fp_slice2 = open("slice_temple.txt","r")

# 開始
puts("引数1 : #{ARGV[0]}\n")
puts("引数2 : #{ARGV[1]}\n")
puts("ファイル書き込み開始\n")
fp_detail.write("[Start]\n")

# 現在読んでいる行
n_readline = 0
str_readlines = nil
tempStrs = nil



# トポロジを読み込み


# 開始
puts("引数1 : #{ARGV[0]}\n")
puts("引数2 : #{ARGV[1]}\n")
puts("引数3 : #{ARGV[3]}\n")
puts("ファイル書き込み開始\n")
fp_detail.write("[Start]\n")

# トポロジを読み込み
fp_topology.each do |line|
  if line[0]=="#"
    next  # コメント行は読み飛ばす
  elsif line.strip.length==0
    next  # 空白行は読み飛ばす
  elsif line.include?("vswitch")
    tempStrs = line.split("\"")
    fp_detail.write("スイッチ\"#{tempStrs[1]}\"を検出\n")
    switches[n_switches] = tempStrs[1]
    n_switches += 1
  elsif line.include?("vhost(")
    tempStrs = line.split("\"")
    tempStrs.each_index do |i| # パラメータを検出したい
      if tempStrs[i].include?("ip ")
        hosts_ip[n_hosts] = tempStrs[i+1]
      elsif tempStrs[i].include?("netmask ")
        hosts_subnet[n_hosts] = tempStrs[i+1]
      end
    end
    fp_detail.write("ホスト\"#{tempStrs[1]}\"を検出。IPアドレス=#{hosts_ip[n_hosts]},サブネットマスク=#{hosts_subnet[n_hosts]}\n")
    hosts[n_hosts] = tempStrs[1]
    n_hosts += 1
  elsif line.include?("link ")
    tempStrs = line.split("\"")
    fp_detail.write("リンク#{tempStrs[1]}->#{tempStrs[3]}を検出\n")
  else
    puts("? : #{line}")
  end
end


# スライス情報を読み込み
str_readlines = fp_slice2.readlines
# 1行目はスライス数
str_readline = str_readlines[n_readline]
n_slice = str_readline.to_i
n_readline += 1
for i in 0...n_slice do
  slice_names[i] = Array.new
  slice_hosts[i] = Array.new
  slice_hostname[i] = Array.new
  slice_hostip[i] = Array.new
  slice_hostsnm[i] = Array.new
  # スライス名
  str_readline = str_readlines[n_readline]
  n_readline += 1
  slice_names[i] = str_readline.chomp
  # スライス内のホスト数
  str_readline = str_readlines[n_readline]
  n_readline += 1
  n_hosts_in_slice[i] = str_readline.to_i
  # 各ホスト情報
  for j in 0...n_hosts_in_slice[i] do
    str_readline = str_readlines[n_readline]
    n_readline += 1
    tempStrs = str_readline.chomp.split(",")
    slice_hosts[i][j] = hosts.index( tempStrs[0] )
    # 以下、topology_controllerのための格納文
    slice_hostname[i][j] = tempStrs[0]
    slice_hostip[i][j] = tempStrs[1]
    slice_hostsnm[i][j] = tempStrs[2]
  end
end



# スライス情報を更新
if ARGV[0]=="create"
  # スライス作成。スライス名を指定
  puts(" -*- create -*- ")
elsif ARGV[0]=="addhost"
  # ホスト追加。スライス名、ホスト名を指定
  puts(" -*- addhost -*- ")
elsif ARGV[0]=="delhost"
  # ホスト削除。スライス名、ホスト名を指定
  puts(" -*- delhost -*- ")
elsif ARGV[0]=="searchhost"
  # ホスト検索。ホスト名のみ指定
  puts(" -*- searchhost -*- ")
else
  puts(" -*- undefined command -*- ")
end

# スライス情報を書き込み
fp_slice.write("#{n_slice}\n")
for i in 0...n_slice do
  fp_slice.write("#{slice_names[i]}\n")
  fp_slice.write("#{n_hosts_in_slice[i]}\n")
  for j in 0...n_hosts_in_slice[i] do
    p = slice_hosts[i][j]
    fp_slice.write("#{hosts[p]},#{hosts_ip[p]},#{hosts_subnet[p]}\n")
  end
end


# 終了
puts("スイッチ : \n#{switches.to_s}\n")
puts("ホスト : \n#{hosts.to_s}\n")
puts("ホストIP : \n#{hosts_ip.to_s}\n")
puts("ホストサブネット : \n#{hosts_subnet.to_s}\n")

fp_detail.write("[End]\n")
puts("ファイル書き込み終了\n")

# ファイルを閉じる（※必須）
fp_topology.close
fp_detail.close
fp_slice.close
fp_slice2.close


