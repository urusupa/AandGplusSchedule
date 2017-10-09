#! ruby -Ku
# encoding: utf-8

require 'rubygems'
require 'mechanize'
require 'nkf'
require 'fileutils'
require 'date'
require 'chronic'
require 'common'

#定数定義

	TargetURL = "http://www.agqr.jp/timetable/streaming.html"

#関数定義開始


def getAandGplusSchedule()
	agent = Mechanize.new
	page = agent.get(TargetURL)

	elements = page.search('//html/body/div[2]/div/table/*').to_html
	elements = elements.gsub(/(\<br\>|\<tr\>\<\/tr\>\n|\t|\<thead class\="scrollHead"\>|\<th style\="width:(.*?)px;"\>\<\/th\>|\<tbody class\="scrollBody scroll\-pane"\>|\<\/thead\>|\<\/tbody\>)/, '')
	elements = elements.gsub(/\<\!\-\-\<span\>\<img src\=\"http\:\/\/cdn\-agqr.joqr.jp\/schedule\/img\/icon_p\.gif\"\>\<\/span\>\-\-\>\n/, '')
	elements = elements.gsub(/\<img src\=\".*schedule\/img\/icon_mail\.gif\"\>/, '')
	elements = elements.gsub(/<div class="rp">\n/, '<div class="rp">')
	elements = elements.gsub(/<div class="title\-p" style="word\-break: break\-all; width: .*?px;">\n/, '<div class="title-p">')
	elements = elements.gsub(/&amp;/, '&')

	arySchedule = Array.new
	arySchedule = elements.split("\n")

	arySchedule.delete_if {|el| el =~ /(^<!--.*-->$|^<\/div>$|^<tr><\/tr>$)/ }
	arySchedule.delete_if(&:empty?)
	
	filehdl = File.open(DATADIR + "AandGplusSchedule.dat","w+")
	arySchedule.each do |e|

		if re = e.match(/\d\d\/\d\d（.）/) then
			filehdl.puts re[0]
		elsif re = e.match(/class=\"time[1-3]\".*\>(.*?)\</) then
			filehdl.puts "[[" + re[1] + "]]"
		elsif re = e.match(/<div class="rp">(.*)/) then
			filehdl.puts "[personality]" + re[1]
		elsif re = e.match(/<td style="width: .*?px\;" rowspan="(.*?)" class="(bg-.*?)">/) then
			filehdl.puts "[[]]\n[bg]" + re[2] + "\n[minutes]" + re[1]
		elsif re = e.match(/(\d\d:\d\d).*?<span><img src="http:\/\/cdn\-agqr\.joqr\.jp\/schedule\/img\/icon_m\.gif\"><\/span>/) then
			filehdl.puts "[time]" + re[1] + "\n[video]enable"
		elsif re = e.match(/(\d\d:\d\d)<\/div>/) then
			filehdl.puts "[time]" + re[1] + "\n[video]disable"
		elsif re = e.match(/<a href="mailto:(.*?)"><\/a>/) then
			filehdl.puts "[mail]" + re[1]
		elsif re = e.match(/<a href="(.*?)" target="_blank"><img src=".*?" alt=".*?" title=".*?"><\/a>/) then
			#filehdl.puts "[link]" + re[1] + "\n[title]" + re[2]
		elsif re = e.match(/<a href="(.*?)" target="_blank">(.*?)<\/a>/) then
			filehdl.puts "[link]" + re[1] + "\n[title]" + re[2]
			#filehdl.puts e
		elsif re = e.match(/<div class="title\-p">(.*)/) then
			filehdl.puts "[link]none" + "\n[title]" + re[1]
		elsif e =~ /(<\/td>|<\/tr>|<tr>|class="bnr"|class="time")/ then
			
		else
			filehdl.puts e
		end
	end

	filehdl.close

rescue => ex
	p ex
else
end


def makeAandGplusSchedule()

	load "#{CONFDIR}/AandGplusSchedule_conf.rb"

	dayofweek = Array.new
	
	filehdl_out = File.open(DATADIR + "ical/AandGplusSchedule.ics","w+")
	filehdl_out.puts @calender_init
	firstbracketflg = 1
	summary = Hash[:dtstamp, "DTSTAMP:" + TIMESTMP[0..7] + "T" + TIMESTMP[8..13], :bg, "", :minutes, "", :time, "", :video, "", :link, "", :title, "", :personality, "", :mail, ""]
	
	filehdl_in = File.open(DATADIR + "AandGplusSchedule.dat","r")
	filehdl_in.each_line { |line|
		if re = line.match(/\[\[\]\]/) then
			if firstbracketflg == 1 then
				filehdl_out.puts "BEGIN:VEVENT"
				filehdl_out.puts "UID:"
				
				firstbracketflg = 0
				@dowcnt = 0

			else
				filehdl_out.puts "SUMMARY:" + summary[:title]
				filehdl_out.puts "DESCRIPTION:" + summary[:personality] + " " + summary[:bg] + " " + summary[:video] + " " + summary[:link] + " " + summary[:mail]
				filehdl_out.puts "CLASS:PUBLIC"
				filehdl_out.puts "TRANSP:TRANSPARENT"
				filehdl_out.puts "STATUS:CONFIRMED"
				filehdl_out.puts "END:VEVENT"
				
				@dowcnt += 1
				@dowcnt = 0 if @dowcnt == 7

				#デバグ用
				#p summary[:title]
				#pp dayofweek

				summary[:bg] = ""
				summary[:minutes] = ""
				summary[:time] = ""
				summary[:video] = ""
				summary[:link] = ""
				summary[:title] = ""
				summary[:personality] = ""
				summary[:mail] = ""
			
				filehdl_out.puts "BEGIN:VEVENT"
				filehdl_out.puts "UID:"
			end
		elsif re = line.match(/([0-9]{1,2})\/([0-9]{1,2})（.）/) then
			#60分間を要素2に持つ。曜日送りの処理で使用する
			dayofweek << [TIMESTMP[0..3] + re[1] + re[2] ,0]
		elsif re = line.match(/\[[0-9]{1,2}\]/) then
			#[[時間]]のときは曜日カーソルを月曜へ
			@dowcnt = 6
			
			#1時間毎に+60分間する
			dayofweek.each{|elem|
				elem[1] = elem[1].to_i + 60
			}
		elsif re = line.match(/\[bg\](.*)/) then
			if re[1] == "bg-repeat" then
				summary[:bg] = "[再放送]"
			elsif re[1] == "bg-f" then
				summary[:bg] = "[初回放送]"
			elsif re[1] == "bg-l" then
				summary[:bg] = "[生放送]"
			elsif re[1] == "bg-etc" then
				summary[:bg] = "[その他]"
			end
		elsif re = line.match(/\[minutes\](.*)/) then
			summary[:minutes] = re[1]
			while dayofweek[@dowcnt][1].to_i <= 0 do
					@dowcnt += 1
					@dowcnt = 0 if @dowcnt == 7
			end

#特別対応、FIVE STARSの時間
			if summary[:minutes].to_i == 35 then
				while dayofweek[@dowcnt][1].to_i == 0 || dayofweek[@dowcnt][1].to_i == 30 do
						@dowcnt += 1
						@dowcnt = 0 if @dowcnt == 7
				end
			end
#特別対応ここまで

			dayofweek[@dowcnt][1] = dayofweek[@dowcnt][1].to_i - re[1].to_i

		elsif re = line.match(/\[time\](.*)/) then
			casttime = dayofweek[@dowcnt][0][0..3] + "/" + dayofweek[@dowcnt][0][4..5] + "/" + dayofweek[@dowcnt][0][6..7] + " " + re[1] + ":00"
			casttime = Chronic.parse(casttime)

			dtstartaddT = casttime.strftime("%Y%m%dT%H%M%S00")
			dtstart = "DTSTART;TZID=Japan:" + dtstartaddT + ";"
			filehdl_out.puts dtstart
			
=begin
#終了時間を表示するか否か
			dtend = casttime + (summary[:minutes].to_i * 60)
			dtend = dtend.strftime("%Y%m%dT%H%M%S00")
			p summary[:minutes]
			p dtstart + " → "+ dtend
=end
			dtend = "DTEND;TZID=Japan:" + dtstartaddT + ";"
			filehdl_out.puts dtend

		elsif re = line.match(/\[video\](.*)/) then
			if re[1] == "enable" then
				summary[:video] = "[動画あり]"
			elsif re[1] == "disable" then
				summary[:video] = "[動画なし]"
			end
		elsif re = line.match(/\[link\](.*)/) then
			if re[1] == "none" then
				summary[:link] = "[リンクなし]"
			else
				summary[:link] = re[1]
			end
		elsif re = line.match(/\[title\](.*)/) then
			summary[:title] = re[1]
		elsif re = line.match(/\[personality\](.*)/) then
			summary[:personality] = re[1]
		elsif re = line.match(/\[mail\](.*)/) then

			summary[:mail] = re[1]

# 特殊対応 セカンドショットアワー「戸松遥のココロ☆ハルカス」「寿美菜子のラフラフ」
			if re[1] == "harukas@joqr.net" then
				next
			elsif re[1] == "375@joqr.net" then
				summary[:mail] = "harukas@joqr.net 375@joqr.net"
			end
# 特殊対応ここまで
		
		else
			filehdl_out.puts line
		end
	}
	
	filehdl_in.close

	filehdl_out.puts "SUMMARY:" + summary[:title]
	filehdl_out.puts "DESCRIPTION:" + summary[:personality] + " " + summary[:bg] + " " + summary[:video] + " " + summary[:link] + " " + summary[:mail]
	filehdl_out.puts "CLASS:PUBLIC"
	filehdl_out.puts "TRANSP:TRANSPARENT"
	filehdl_out.puts "STATUS:CONFIRMED"
	filehdl_out.puts "END:VEVENT"
	filehdl_out.puts "END:VCALENDAR"
	filehdl_out.close
	
	#pp dayofweek
rescue => ex
	p ex
else
end

def moveIcsForHost()
	FileUtils.cp(DATADIR + "ical/AandGplusSchedule.ics", BKUPDIR + "ical/AandGplusSchedule.ics")
	FileUtils.cp(DATADIR + "ical/AandGplusSchedule.ics", WWWDIR + "icalendar/AandGplusSchedule.ics")
rescue => ex
	APPEND_LOGFILE("・ファイル移動異常終了")
	APPEND_LOGFILE(ex)
else
	PARCON_SQL.normal('AandGplusSchedule.ics', __FILE__.gsub(/^.*\//,'') )
	APPEND_LOGFILE("・ファイル移動正常終了")
end


getAandGplusSchedule()
makeAandGplusSchedule()
moveIcsForHost()
