$downloadlDir = '../spoluziaci-docs/'
$proxy = ''

$baseUrl = 'http://www.spoluziaci.sk/'
$mechanizeLog = 'mechanize.log'
$cookies_file = "cookies.jar"
$passwd = '.key'
$class_year = '2014'
$class_field = 'AI'
$class_list_regexp = /moj[ae] tried[ay]/
$login_form_regexp = /login/
$logout_link_regexp = /Odhl..?si..? sa/

# A bit logic to determine the HTTP_PROXY settings
begin
  require 'uri'
  proxy_http = ENV['HTTP_PROXY']
  proxy_http ||= ENV['http_proxy']
  uri = URI.parse(proxy_http)
  $proxy_user, $proxy_pass = uri.userinfo.split(/:/) if uri.userinfo
  $proxy_host = uri.host
  $proxy_port = uri.port
  $proxy_use = true
rescue
  $proxy_use = false
end

