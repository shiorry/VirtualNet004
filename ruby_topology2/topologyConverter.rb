
# 練習
str = "Hello, world."
puts("文字列：#{str}\n")
puts("部分文字列[3..7]：#{str[3..7]}\n")

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
slice_hosts = Array.new # 配列を要素に持つ配列。ホストの添字を代入したい。
n_hosts_in_slice = Array.new
n_slice = 0

# ファイルパス
fp_topology = open("top13.conf","r")
fp_slice = open("slice.txt","w")
fp_detail = open("detail.txt","w")

# 開始
puts("引数1 : #{ARGV[0]}\n")
puts("引数2 : #{ARGV[1]}\n")
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

# スライス情報を更新

slice_hosts[0] = Array.new
slice_hosts[0][0] = 0
slice_hosts[0][1] = 1
slice_hosts[0][2] = 2
n_hosts_in_slice = 3
n_slice += 1
slice_hosts[1] = Array.new
slice_hosts[1][0] = 3
slice_hosts[1][1] = 4
slice_hosts[1][2] = 5
slice_hosts[1][3] = 6
n_hosts_in_slice = 4
n_slice += 1

# スライス情報を書き込み
fp_slice.write("n_slice=#{n_slice}\n")
i=0
while i<n_slice
  fp_slice.write("slice #{i} {\n")
  slice_hosts[i].each do |num|
    fp_slice.write("#{hosts[num]},#{hosts_ip[num]},#{hosts_subnet[num]}\n")
  end
  fp_slice.write("}\n")
  i+=1
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
fp_slice.close


