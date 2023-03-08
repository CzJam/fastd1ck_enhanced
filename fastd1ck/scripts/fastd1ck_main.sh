#!/bin/sh

eval `dbus export fastd1ck_`

# 声明常量
if [ "$fastd1ck_protocal" == "300" ];then
	# protocal 300
	readonly packageName='com.xunlei.vip.swjsq'
	readonly protocolVersion=300
	readonly businessType=68
	readonly sdkVersion='3.1.2.185150'
	readonly clientVersion='2.7.2.0'
	readonly agent_xl="android-ok-http-client/xl-acc-sdk/version-$sdkVersion"
	readonly agent_down='okhttp/3.9.1'
	readonly agent_up='android-async-http/xl-acc-sdk/version-1.0.0.1'
	readonly client_type_down='android-swjsq'
	readonly client_type_up='android-uplink'
elif [ "$fastd1ck_protocal" == "200" ];then
# protocal 200
	readonly packageName='com.xunlei.vip.swjsq'
	readonly protocolVersion=200
	readonly businessType=68
	readonly sdkVersion='2.1.1.177662'
	readonly clientVersion='2.4.1.3'
	readonly agent_xl="android-async-http/xl-acc-sdk/version-$sdkVersion"
	readonly agent_down='okhttp/3.4.1'
	readonly agent_up='android-async-http/xl-acc-sdk/version-1.0.0.1'
	readonly client_type_down='android-swjsq'
	readonly client_type_up='android-uplink'
	readonly UA_XL="User-Agent: swjsq/0.0.1"
fi

# 声明全局变量
_bind_ip=
_http_cmd=
_peerid=
_devicesign=
_devid=
_userid=
_loginkey=
_sessionid=
_portal_down=
_portal_up=
_dial_account=
access_url=
http_args=
user_agent=
link_cn=
lasterr=
sequence_xl=1000000
sequence_down=$(( $(date +%s) / 6 ))
sequence_up=$sequence_down

# 包含用于解析 JSON 格式返回值的函数
#. /koolshare/bin/jshn.sh
json_init(){
	POST_DATA='{}'
}

json_add_string(){
	POST_DATA=`echo $POST_DATA | jq --arg var "$2" '. + {'$1': $var}'`
}

json_close_object(){
	POST_DATA=`echo $POST_DATA | jq .`
}

json_dump() {
	echo $POST_DATA
}

json_cleanup(){
	READ=""
}

json_load(){
	READ=`echo $1 | jq . -c`
	READ_ORGIN="$READ"
}

json_get_var(){
	v=`echo $READ | jq -r ."$2"`
	[ "$v" == "null" ] && v=""
	eval $1="$v"
	[ -z "$v" ] && return 1 || return 0
}

json_select(){
	[ -z "$1" ] && [ -z "$mark" ] && RED_TMP=$READ
	[ -z "$1" ] && [ -n "$mark" ] && READ=$RED_TMP && mark=""

	[[ "$1" == ".." ]] && {
		READ=$READ_ORGIN && return 0
	}
	
	READ=`echo $READ | jq -r ."$1"` && mark=1
	[ "$READ" == "null" ] && return 1 || return 0
}
# 日志和状态栏输出。1 日志文件, 2 系统日志, 4 详细模式, 8 下行状态栏, 16 上行状态栏, 32 失败状态
_log() {
	local msg=$1 flag=$2 timestamp=$(date +'%Y/%m/%d %H:%M:%S')
	[ -z "$msg" ] && return
	[ -z "$flag" ] && flag=1

	[ $logging -eq 0 -a $(( $flag & 1 )) -ne 0 ] && flag=$(( $flag ^ 1 ))
	if [ $verbose -eq 0 -a $(( $flag & 4 )) -ne 0 ]; then
		[ $(( $flag & 1 )) -ne 0 ] && flag=$(( $flag ^ 1 ))
		[ $(( $flag & 2 )) -ne 0 ] && flag=$(( $flag ^ 2 ))
	fi
	if [ $down_acc -eq 0 -a $(( $flag & 8 )) -ne 0 ]; then
		flag=$(( $flag ^ 8 ))
		[ $up_acc -ne 0 ] && flag=$(( $flag | 16 ))
	fi
	if [ $up_acc -eq 0 -a $(( $flag & 16 )) -ne 0 ]; then
		flag=$(( $flag ^ 16 ))
		[ $down_acc -ne 0 ] && flag=$(( $flag | 8 ))
	fi

	[ $(( $flag & 1 )) -ne 0 ] && echo "$timestamp $msg" >> $LOGFILE 2> /dev/null
	[ $(( $flag & 2 )) -ne 0 ] && logger "$NAME" "$msg"

	[ $(( $flag & 32 )) -eq 0 ] && local color="#09EE04" || local color="#FFCC00"
	#[ $(( $flag & 8 )) -ne 0 ] && echo -n "<font color=$color>$timestamp $msg</font>" > $down_state_file 2> /dev/null
	#[ $(( $flag & 16 )) -ne 0 ] && echo -n "<font color=$color>$timestamp $msg</font>" > $up_state_file 2> /dev/null
	[ $(( $flag & 8 )) -ne 0 ] && dbus set fastd1ck_status_rx="<font color=$color>$timestamp $msg</font>"
	[ $(( $flag & 16 )) -ne 0 ] && dbus set fastd1ck_status_tx="<font color=$color>$timestamp $msg</font>" > $up_state_file 2> /dev/null
}

# 清理日志
clean_log() {
	[ $logging -eq 1 -a -f "$LOGFILE" ] || return
	[ $(wc -l "$LOGFILE" | awk '{print $1}') -le 800 ] && return
	_log "清理日志文件"
	local logdata=$(tail -n 500 "$LOGFILE")
	echo "$logdata" > $LOGFILE 2> /dev/null
	unset logdata
}

# 获取接口IP地址
get_bind_ip(){
	#双WAN判断
	wans_mode=$(nvram get wans_mode)
	wan0_addr=$(nvram get wan0_ipaddr)
	wan1_addr=$(nvram get wan1_ipaddr)
	if [ "$fastd1ck_if" == "1" ];then
		_bind_ip="$wan0_addr"
	elif [ "$fastd1ck_if" == "2" ];then
		_bind_ip="$wan1_addr"
	else
		_bind_ip="$wan_addr"
	fi
	
	if [ -z "$_bind_ip" -o "$_bind_ip"x == "0.0.0.0"x ]; then
		_log "获取网络 wan$network IP地址失败"
		return 1
	else
		_log "绑定IP地址: $_bind_ip"
		return 0
	fi		
}

# 定义基本 HTTP 命令和参数
gen_http_cmd() {
	_http_cmd="wget -q -nv -t 1 -T 5 --no-check-certificate -O - "
	_http_cmd="$_http_cmd --bind-address=$_bind_ip"
}

# 300
swjsq_json() {
	let sequence_xl++
	# 生成POST数据
	if [ "$fastd1ck_protocal" == "300" ];then
		json_init
		json_add_string protocolVersion "$protocolVersion"
		json_add_string sequenceNo "$sequence_xl"
		json_add_string platformVersion '10'
		json_add_string isCompressed '0'
		json_add_string appid "$businessType"
		json_add_string clientVersion "$clientVersion"
		json_add_string peerID "$_peerid"
		json_add_string appName "ANDROID-$packageName"
		json_add_string sdkVersion "${sdkVersion##*.}"
		json_add_string devicesign "$fastd1ck_devid"
		json_add_string netWorkType 'WIFI'
		json_add_string providerName 'OTHER'
		json_add_string deviceModel "$fastd1ck_brand"
		json_add_string deviceName "$fastd1ck_model"
		json_add_string OSVersion "10"
	elif [ "$fastd1ck_protocal" == "200" ];then
		json_init
		json_add_string protocolVersion "$protocolVersion"
		json_add_string sequenceNo "$sequence_xl"
		json_add_string platformVersion '2'
		json_add_string isCompressed '0'
		json_add_string businessType "$businessType"
		json_add_string clientVersion "$clientVersion"
		json_add_string peerID "$_peerid"
		json_add_string appName "ANDROID-$packageName"
		json_add_string sdkVersion "${sdkVersion##*.}"
		json_add_string devicesign "$fastd1ck_devid"
		json_add_string deviceModel "$fastd1ck_brand"
		json_add_string deviceName "$fastd1ck_model"
		json_add_string OSVersion "10"
		#json_add_string deviceModel "R1"
		#json_add_string deviceName "SmallRice R1"
		#json_add_string OSVersion "5.0.1"
	fi
}

# 帐号登录
swjsq_login() {
	swjsq_json
	if [ -z "$_userid" -o -z "$_loginkey" ]; then
		access_url='https://mobile-login.xunlei.com:443/login'
		json_add_string userName "$username"
		json_add_string passWord "$password"
		json_add_string verifyKey
		json_add_string verifyCode
		[ "$fastd1ck_protocal" == "300" ] && json_add_string isMd5Pwd '0'
	else
		access_url='https://mobile-login.xunlei.com:443/loginkey'
		json_add_string userName "$_userid"
		json_add_string loginKey "$_loginkey"
	fi
	json_close_object
		_log "模拟机型：$fastd1ck_brand $fastd1ck_model"  
		_log "设备标识：$fastd1ck_devid"

	if [ "$fastd1ck_protocal" == "300" ]; then
		local ret=$($_http_cmd --user-agent="$agent_xl" "$access_url" --post-data="$(json_dump)")
	else
		local ret=$($_http_cmd "$access_url" --post-data="$(json_dump)" --header "$UA_XL") 
	fi
	case $? in
		0)
			#_log "login is $(echo $ret|jq .|sed '1i --------------------------------------------------------------------------'|sed '$a --------------------------------------------------------------------------'|sed 'N;2i')" $(( 1 | 4 ))
			_log "login is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
			json_cleanup; json_load "$ret" >/dev/null 2>&1
			json_get_var lasterr "errorCode"
			;;
		2) lasterr=-2;;
		4) lasterr=-3;;
		*) lasterr=-1;;
	esac
	case ${lasterr:=-1} in
		0)
			json_get_var _userid "userID"
			json_get_var _loginkey "loginKey"
			json_get_var _sessionid "sessionID"
			_log "_sessionid is $_sessionid" $(( 1 | 4 ))
			local outmsg="帐号登录成功"; _log "$outmsg" $(( 1 | 8 ))
			;;
		15) # 身份信息已失效
			_userid=; _loginkey=;;
		-1)
			local outmsg="帐号登录失败。迅雷服务器未响应，请稍候"; _log "$outmsg";;
		-2)
			local outmsg="Wget 参数解析错误，请更新 GNU Wget"; _log "$outmsg" $(( 1 | 8 | 32 ));;
		-3)
			local outmsg="Wget 网络通信失败，请稍候"; _log "$outmsg";;
		*)
			local errorDesc; json_get_var errorDesc "errorDesc"
			local outmsg="帐号登录失败。错误代码: ${lasterr}"; \
				[ -n "$errorDesc" ] && outmsg="${outmsg}，原因: $errorDesc"; _log "$outmsg" $(( 1 | 8 | 32 ));;
	esac
	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 帐号注销
swjsq_logout() {
	swjsq_json
	json_add_string userID "$_userid"
	json_add_string sessionID "$_sessionid"
	json_close_object

	local ret=$($_http_cmd --user-agent="$agent_xl" 'https://mobile-login.xunlei.com/logout' --post-data="$(json_dump)")
	_log "logout is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errorCode"

	case ${lasterr:=-1} in
		0)
			_sessionid=
			local outmsg="帐号注销成功"; _log "$outmsg" $(( 1 | 8 ));;
		-1)
			local outmsg="帐号注销失败。迅雷服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local errorDesc; json_get_var errorDesc "errorDesc"
			local outmsg="帐号注销失败。错误代码: ${lasterr}"; \
				[ -n "$errorDesc" ] && outmsg="${outmsg}，原因: $errorDesc"; _log "$outmsg" $(( 1 | 8 | 32 ));;
	esac

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 获取用户信息
swjsq_getuserinfo() {
	local _vasid vasid_down=14 vasid_up=33 outmsg
	[ $down_acc -ne 0 ] && _vasid="${_vasid}${vasid_down},"; [ $up_acc -ne 0 ] && _vasid="${_vasid}${vasid_up},"
	swjsq_json
	json_add_string userID "$_userid"
	json_add_string sessionID "$_sessionid"
	json_add_string vasid "$_vasid"
	json_close_object

	local ret=$($_http_cmd --user-agent="$agent_xl" 'https://mobile-login.xunlei.com/getuserinfo' --post-data="$(json_dump)")
	_log "getuserinfo is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errorCode"

	case ${lasterr:=-1} in
		0)
			local index=0 can_down=0 vasid isVip isYear expireDate
			#json_select "vipList" >/dev/null 2>&1
			while : ; do
				#json_select $index >/dev/null 2>&1
				json_select "vipList[$index]"
				[ $? -ne 0 ] && break
				json_get_var vasid "vasid"
				json_get_var isVip "isVip"
				json_get_var isYear "isYear"
				json_get_var expireDate "expireDate"
				json_select ".." >/dev/null 2>&1
				let index++

				case ${vasid:-0} in
					2) [ $down_acc -ne 0 ] && outmsg="迅雷超级会员" || continue;;
					$vasid_down) outmsg="迅雷快鸟会员（下行）";;
					$vasid_up) outmsg="上行提速会员";;
					*) outmsg="" && continue;;
				esac
				if [ ${isVip:-0} -eq 1 -o ${isYear:-0} -eq 1 ]; then
					outmsg="${outmsg}有效。会员到期时间：${expireDate:0:4}-${expireDate:4:2}-${expireDate:6:2}"
					if [ $vasid -eq $vasid_up ];then
						_log "$outmsg" $(( 1 | 16 ))
					else
						_log "$outmsg" $(( 1 | 8 ))
					fi
					[ $vasid -ne $vasid_up ] && can_down=$(( $can_down | 1 ))
				else
					if [ ${#expireDate} -ge 8 ]; then
						outmsg="${outmsg}已到期。会员到期时间：${expireDate:0:4}-${expireDate:4:2}-${expireDate:6:2}"
					else
						outmsg="${outmsg}无效"
					fi
					
					if [ $vasid -eq $vasid_up ]; then 
						_log "$outmsg" $(( 1 | 16 | 32 ))
					else
						_log "$outmsg" $(( 1 | 8 | 32 ))
					fi
					[ $vasid -eq $vasid_up ] && up_acc=0
				fi
			done
			[ $can_down -eq 0 ] && down_acc=0
			;;
		-1)
			outmsg="获取迅雷会员信息失败。迅雷服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local errorDesc; json_get_var errorDesc "errorDesc"
			outmsg="获取迅雷会员信息失败。错误代码: ${lasterr}"; \
				[ -n "$errorDesc" ] && outmsg="${outmsg}，原因: $errorDesc"; _log "$outmsg" $(( 1 | 8 | 32 ));;
	esac

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 登录时间更新
swjsq_renewal() {
	xlnetacc_var 1
	local limitdate=$(date +%Y%m%d -d "1970.01.01-00:00:$(( $(date +%s) + 30 * 24 * 60 * 60 ))")

	access_url='http://api.ext.swjsq.vip.xunlei.com'
	local ret=$($_http_cmd --user-agent="$user_agent" "$access_url/renewal?${http_args%&dial_account=*}&limitdate=$limitdate")
	_log "renewal is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errno"

	case ${lasterr:=-1} in
		0)
			local outmsg="更新登录时间成功。帐号登录周期：${limitdate:0:4}-${limitdate:4:2}-${limitdate:6:2}"; _log "$outmsg";;
		-1)
			local outmsg="更新登录时间失败。迅雷服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local message; json_get_var message "richmessage"
			local outmsg="更新登录时间失败。错误代码: ${lasterr}"; \
				[ -n "$message" ] && outmsg="${outmsg}，原因: $message"; _log "$outmsg" $(( 1 | 8 | 32 ));;
	esac

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 获取提速入口
swjsq_portal() {
	xlnetacc_var $1

	[ $1 -eq 1 ] && access_url='http://api.portal.swjsq.vip.xunlei.com:81/v2/queryportal' || \
		access_url='http://api.upportal.swjsq.vip.xunlei.com/v2/queryportal'
	local ret=$($_http_cmd --user-agent="$user_agent" "$access_url")
	_log "portal $1 is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errno"

	case ${lasterr:=-1} in
		0)
			local interface_ip interface_port province sp
			json_get_var interface_ip "interface_ip"
			json_get_var interface_port "interface_port"
			json_get_var province "province_name"
			json_get_var sp "sp_name"
			if [ $1 -eq 1 ]; then
				_portal_down="http://$interface_ip:$interface_port/v2"
				_log "_portal_down is $_portal_down" $(( 1 | 4 ))
			else
				_portal_up="http://$interface_ip:$interface_port/v2"
				_log "_portal_up is $_portal_up" $(( 1 | 4 ))
			fi
			local outmsg="获取${link_cn}提速入口成功"; \
				[ -n "$province" -a -n "$sp" ] && outmsg="${outmsg}。运营商：${province}${sp}"; _log "$outmsg" $(( 1 | $1 * 8 ))
			;;
		-1)
			local outmsg="获取${link_cn}提速入口失败。迅雷服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local message; json_get_var message "message"
			local outmsg="获取${link_cn}提速入口失败。错误代码: ${lasterr}"; \
				[ -n "$message" ] && outmsg="${outmsg}，原因: $message"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
	esac

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 获取网络带宽信息
isp_bandwidth() {
	xlnetacc_var $1

	local ret=$($_http_cmd --user-agent="$user_agent" "$access_url/bandwidth?${http_args%&dial_account=*}")
	_log "bandwidth $1 is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errno"

	case ${lasterr:=-1} in
		0)
			# 获取带宽数据
			local can_upgrade bind_dial_account dial_account stream cur_bandwidth max_bandwidth
			[ $1 -eq 1 ] && stream="downstream" || stream="upstream"
			json_get_var can_upgrade "can_upgrade"
			json_get_var bind_dial_account "bind_dial_account"
			json_get_var dial_account "dial_account"
			json_select "bandwidth" >/dev/null 2>&1
			json_get_var cur_bandwidth "$stream"
			json_select ..
			json_select "max_bandwidth" >/dev/null 2>&1
			json_get_var max_bandwidth "$stream"
			json_select ..
			cur_bandwidth=$(( ${cur_bandwidth:-0} / 1024 ))
			max_bandwidth=$(( ${max_bandwidth:-0} / 1024 ))

			if [ -n "$bind_dial_account" -a "$bind_dial_account" != "$dial_account" ]; then
				local outmsg="绑定宽带账号 $bind_dial_account 与当前宽带账号 $dial_account 不一致，请联系迅雷客服解绑（每月仅一次）"; \
					_log "$outmsg" $(( 1 | 8 | 32 ))
				down_acc=0; up_acc=0
			elif [ $can_upgrade -eq 0 ]; then
				local message; json_get_var message "richmessage"; [ -z "$message" ] && json_get_var message "message"
				local outmsg="${link_cn}无法提速"; \
					[ -n "$message" ] && outmsg="${outmsg}，原因: $message"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ))
				[ $1 -eq 1 ] && down_acc=0 || up_acc=0
			elif [ $cur_bandwidth -ge $max_bandwidth ]; then
				local outmsg="${link_cn}无需提速。当前带宽 ${cur_bandwidth}M，超过最大可提升带宽 ${max_bandwidth}M"; \
					_log "$outmsg" $(( 1 | $1 * 8 ))
				[ $1 -eq 1 ] && down_acc=0 || up_acc=0
			else
				if [ -z "$_dial_account" -a -n "$dial_account" ]; then
					_dial_account=$dial_account
					_log "_dial_account is $_dial_account" $(( 1 | 4 ))
				fi
				local outmsg="${link_cn}可以提速。当前带宽 ${cur_bandwidth}M，可提升至 ${max_bandwidth}M"; _log "$outmsg" $(( 1 | $1 * 8 ))
			fi
			;;
		724) # 724 账号存在异常
			lasterr=-2
			local outmsg="获取${link_cn}网络带宽信息失败。原因: 您的账号存在异常，请联系迅雷客服反馈"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
		3103) # 3103 线路暂不支持
			lasterr=0
			local province sp
			json_get_var province "province_name"; json_get_var sp "sp_name"
			local outmsg="${link_cn}无法提速。原因: ${province}${sp}线路暂不支持"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ))
			[ $1 -eq 1 ] && down_acc=0 || up_acc=0
			;;
		-1)
			local outmsg="获取${link_cn}网络带宽信息失败。运营商服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local message; json_get_var message "richmessage"; [ -z "$message" ] && json_get_var message "message"
			local outmsg="获取${link_cn}网络带宽信息失败。错误代码: ${lasterr}"; \
				[ -n "$message" ] && outmsg="${outmsg}，原因: $message"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
	esac

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 发送带宽提速信号
isp_upgrade() {
	xlnetacc_var $1

	local ret=$($_http_cmd --user-agent="$user_agent" "$access_url/upgrade?$http_args")
	_log "upgrade $1 is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errno"

	case ${lasterr:=-1} in
		0)
			local bandwidth
			json_select "bandwidth" >/dev/null 2>&1
			json_get_var bandwidth "downstream"
			bandwidth=$(( ${bandwidth:-0} / 1024 ))
			local outmsg="🎉${link_cn}带宽提速成功🎉"; _log "$outmsg" $(( 1 | $1 * 8 ))
			[ $1 -eq 1 ] && down_acc=2 || up_acc=2
			;;
		812) # 812 已处于提速状态
			lasterr=0
			local outmsg="${link_cn}带宽提速无效，请稍后再试！"; _log "$outmsg" $(( 1 | $1 * 8 ))
			[ $1 -eq 1 ] && down_acc=2 || up_acc=2
			;;
		724) # 724 账号存在异常
			lasterr=-2
			local outmsg="${link_cn}提速失败。原因: 您的账号存在异常，请联系迅雷客服反馈"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
		-1)
			local outmsg="${link_cn}提速失败。运营商服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local message; json_get_var message "richmessage"; [ -z "$message" ] && json_get_var message "message"
			local outmsg="${link_cn}提速失败。错误代码: ${lasterr}"; \
				[ -n "$message" ] && outmsg="${outmsg}，原因: $message"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
	esac
	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 发送提速心跳信号
isp_keepalive() {
	xlnetacc_var $1

	local ret=$($_http_cmd --user-agent="$user_agent" "$access_url/keepalive?$http_args")
	_log "keepalive $1 is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errno"

	case ${lasterr:=-1} in
		0)
			local outmsg="${link_cn}心跳信号返回正常"; _log "$outmsg";;
		513) # 513 提速通道不存在
			lasterr=-2
			local outmsg="${link_cn}提速超时，提速通道不存在"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
		-1)
			local outmsg="${link_cn}心跳信号发送失败。运营商服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local message; json_get_var message "richmessage"; [ -z "$message" ] && json_get_var message "message"
			local outmsg="${link_cn}提速失效。错误代码: ${lasterr}"; \
				[ -n "$message" ] && outmsg="${outmsg}，原因: $message"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
	esac

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 发送带宽恢复信号
isp_recover() {
	xlnetacc_var $1

	local ret=$($_http_cmd --user-agent="$user_agent" "$access_url/recover?$http_args")
	_log "recover $1 is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errno"

	case ${lasterr:=-1} in
		0)
			local outmsg="${link_cn}带宽已恢复"; _log "$outmsg" $(( 1 | $1 * 8 ))
			[ $1 -eq 1 ] && down_acc=1 || up_acc=1;;
		-1)
			local outmsg="${link_cn}带宽恢复失败。运营商服务器未响应，请稍候"; _log "$outmsg";;
		*)
			local message; json_get_var message "richmessage"; [ -z "$message" ] && json_get_var message "message"
			local outmsg="${link_cn}带宽恢复失败。错误代码: ${lasterr}"; \
				[ -n "$message" ] && outmsg="${outmsg}，原因: $message"; _log "$outmsg" $(( 1 | $1 * 8 | 32 ));;
	esac

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 查询提速信息，未使用
isp_query() {
	xlnetacc_var $1

	local ret=$($_http_cmd --user-agent="$user_agent" "$access_url/query_try_info?$http_args")
	_log "query_try_info $1 is $(echo $ret|jq .|sed 'N;2i')" $(( 1 | 4 ))
	json_cleanup; json_load "$ret" >/dev/null 2>&1
	json_get_var lasterr "errno"

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 设置参数变量
xlnetacc_var() {
	if [ $1 -eq 1 ]; then
		let sequence_down++
		access_url=$_portal_down
		http_args="sequence=${sequence_down}&client_type=${client_type_down}-${clientVersion}&client_version=${client_type_down//-/}-${clientVersion}&chanel=umeng-10900011&time_and=$(date +%s)000"
		user_agent=$agent_down
		link_cn="下行"
	else
		let sequence_up++
		access_url=$_portal_up
		http_args="sequence=${sequence_up}&client_type=${client_type_up}-${clientVersion}&client_version=${client_type_up//-/}-${clientVersion}"
		user_agent=$agent_up
		link_cn="上行"
	fi
	http_args="${http_args}&peerid=${_peerid}&userid=${_userid}&sessionid=${_sessionid}&user_type=1&os=android-7.1.1"
	[ -n "$_dial_account" ] && http_args="${http_args}&dial_account=${_dial_account}"
}

# 重试循环
xlnetacc_retry() {
	if [ $# -ge 3 ] && [ $3 -ne 0 ]; then
		[ $2 -eq 1 ] && [ $down_acc -ne $3 ] && return 0
		[ $2 -eq 2 ] && [ $up_acc -ne $3 ] && return 0
	fi
	local retry=1
	while : ; do
		lasterr=
		eval $1 $2 && break # 成功
		[ $# -ge 4 ] && [ $retry -ge $4 ] && break || let retry++ # 重试超时
		case $lasterr in
			-1) sleep 5s;; # 服务器未响应
			-2) break;; # 严重错误
			*) sleep 3s;; # 其它错误
		esac
	done
	[ ${lasterr:-0} -eq 0 ] && return 0 || return 1
}

# 注销已登录帐号
xlnetacc_logout() {
	[ -z "$_sessionid" ] && return 2
	[ $# -ge 1 ] && local retry=$1 || local retry=1

	xlnetacc_retry 'isp_recover' 1 2 $retry
	xlnetacc_retry 'isp_recover' 2 2 $retry
	xlnetacc_retry 'swjsq_logout' 0 0 $retry
	[ $down_acc -ne 0 ] && down_acc=1; [ $up_acc -ne 0 ] && up_acc=1
	_sessionid=; _dial_account=

	[ $lasterr -eq 0 ] && return 0 || return 1
}

# 中止信号处理
sigterm() {
	_log "trap sigterm, exit" $(( 1 | 4 ))
	xlnetacc_logout
	#rm -f "$down_state_file" "$up_state_file"
	dbus remove fastd1ck_status_rx
	dbus remove fastd1ck_status_tx
	_log "停止插件！"
	dbus set fastd1ck_enable=0
	exit 0
}

# 初始化
xlnetacc_init() {
	[ "$1" != "--start" ] && return 1

	# 防止重复启动
	local pid
	for pid in $(pidof "${0##*/}"); do
		[ $pid -ne $$ ] && return 1
	done

	# 读取设置
	readonly NAME=xlnetacc
	#readonly LOGFILE=/var/log/${NAME}.log
	readonly LOGFILE=/tmp/upload/fastd1ck_log.txt
	#readonly down_state_file=/var/state/${NAME}_down_state
	#readonly up_state_file=/var/state/${NAME}_up_state
	down_acc=$fastd1ck_dn_enable
	up_acc=$fastd1ck_up_enable
	readonly logging=$fastd1ck_logging
	readonly verbose=$fastd1ck_logging_v
	network=$fastd1ck_if
	keepalive=$fastd1ck_keepalive
	relogin=$fastd1ck_relogin
	readonly username=$fastd1ck_user
	readonly password=$fastd1ck_passwd
	local enabled=$fastd1ck_enable
	([ $enabled -eq 0 ] || [ $down_acc -eq 0 -a $up_acc -eq 0 ] || [ -z "$username" -o -z "$password" -o -z "$network" ]) && return 2
	([ -z "$keepalive" -o -n "${keepalive//[0-9]/}" ] || [ $keepalive -lt 5 -o $keepalive -gt 60 ]) && keepalive=10
	readonly keepalive=$(( $keepalive ))
	([ -z "$relogin" -o -n "${relogin//[0-9]/}" ] || [ $relogin -gt 48 ]) && relogin=0
	readonly relogin=$(( $relogin * 60 * 60 ))

	[ $logging -eq 1 ] && [ ! -d /var/log ] && mkdir -p /var/log
	[ -f "$LOGFILE" ] && _log "--------------------------------------------------------------------------"
	_log "迅雷快鸟正在启动..."

	# 捕获中止信号
	trap 'sigterm' INT # Ctrl-C
	trap 'sigterm' QUIT # Ctrl-\
	trap 'sigterm' TERM # kill

	# 生成设备标识
	readonly _devicesign=$fastd1ck_device_sign
	readonly _peerid=$fastd1ck_peerid
	_log "devicesign: $fastd1ck_device_sign" $(( 1 | 4 ))
	_log "peerid: $_peerid" $(( 1 | 4 ))
	# gen_device_sign
	[ ${#_peerid} -ne 16 -o ${#_devicesign} -ne 71 ] && return 4

	clean_log
	[ -d /var/state ] || mkdir -p /var/state
	#rm -f "$down_state_file" "$up_state_file"
	dbus remove fastd1ck_status_rx
	dbus remove fastd1ck_status_tx
	return 0
}

# 程序主体
xlnetacc_main() {
	while : ; do
		# 获取外网IP地址
		xlnetacc_retry 'get_bind_ip'
		gen_http_cmd

		# 注销快鸟帐号
		xlnetacc_logout 3 && sleep 3s

		# 登录快鸟帐号
		while : ; do
			lasterr=
			swjsq_login
			case $lasterr in
				0) break;; # 登录成功
				-1) sleep 5s;; # 服务器未响应
				-2) return 7;; # Wget 参数解析错误
				-3) sleep 3s;; # Wget 网络通信失败
				6) sleep 130m;; # 需要输入验证码
				8) sleep 3m;; # 服务器系统维护
				15) sleep 1s;; # 身份信息已失效
				*) return 5;; # 登录失败
			esac
		done

		# 获取用户信息
		xlnetacc_retry 'swjsq_getuserinfo'
		[ $down_acc -eq 0 -a $up_acc -eq 0 ] && break
		# 登录时间更新
		xlnetacc_retry 'swjsq_renewal'
		# 获取提速入口
		xlnetacc_retry 'swjsq_portal' 1 1
		xlnetacc_retry 'swjsq_portal' 2 1
		# 获取带宽信息
		xlnetacc_retry 'isp_bandwidth' 1 1 10 || { sleep 3m; continue; }
		xlnetacc_retry 'isp_bandwidth' 2 1 10 || { sleep 3m; continue; }
		[ $down_acc -eq 0 -a $up_acc -eq 0 ] && break
		# 带宽提速
		xlnetacc_retry 'isp_upgrade' 1 1 10 || { sleep 3m; continue; }
		xlnetacc_retry 'isp_upgrade' 2 1 10 || { sleep 3m; continue; }

		# 心跳保持
		local timer=$(date +%s)
		while : ; do
			clean_log # 清理日志
			sleep ${keepalive}m
			[ $relogin -ne 0 -a $(( $(date +%s) - $timer )) -ge $relogin ] && break # 登录超时
			xlnetacc_retry 'isp_keepalive' 1 2 5 || break
			xlnetacc_retry 'isp_keepalive' 2 2 5 || break
		done
	done
	xlnetacc_logout
	_log "无法提速，迅雷快鸟已停止。"
	return 6
}

# 程序入口
xlnetacc_init "$@" && xlnetacc_main
_log "停止插件！"
dbus set fastd1ck_enable=0

exit $?