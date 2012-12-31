require 'rubygems'
require 'pp'
require 'mechanize'
require 'nokogiri'
require 'logger'
require 'readline'
require 'aes_crypter'
require 'link_extractor'
require 'my_logger'

$downloadlDir = 'downloads/'
$baseUrl = 'http://www.spoluziaci.sk/'
$mechanizeLog = 'mechanize.log'
$cookies_file = "cookies.jar"
$passwd = '.key'
$class_year = '2014'
$class_field = 'AI'
$class_list_regexp = /moj[ae] tried[ay]/
$login_form_regexp = /login/
$logout_link_regexp = /Odhl..?si..? sa/

class SpoluziaciCrawler
  include MyLogger
  include AESCrypter
  def initialize(download_dir)
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Linux Firefox'
    @agent.follow_meta_refresh = true
    @agent.redirect_ok = true
    @agent.log = Logger.new $mechanizeLog
    @extractor = DocumentLinkExtractor.new
    @download_dir = download_dir
  end

  def crawl
    account = doLogin
    if $cookies_file != nil
      doSaveCookies $cookies_file
    end

    classlist = goClassList(account)
    myclass = goClass(classlist)
    docroot = goDocRoot(myclass)
    docroot_html = docroot.body

    folders = lookupFolders(docroot_html)
    files = processFoldersIntoFiles(folders)

    processFiles(files)

    doLogout
  end

  def doLogin
    homepage = goHomepage
    log "Submitting Login info"
    account_page = homepage.form_with(:action => $login_form_regexp) do |login_form|
      login_form.email = decrypted[:login]
      login_form.password = decrypted[:pass]
    end.
    submit
  end

  def doLogout
    log "Logging out"
    goLinkRegex @agent.current_page, $logout_link_regexp
  end

  def goHomepage
    log "Requesting Homepage"
    @agent.get($baseUrl)
  end

  def goClassList(account_page)
    log "Requesting List of classes"
    goLinkRegex(account_page, $class_list_regexp)
  end

  def goClass(classlist_page)
    goLinkRegex(classlist_page, /#{$class_year}.*#{$class_field}/)
  end

  def goLinkRegex(page, regexp)
    log "Clicking on link matching regexp #{regexp}"
    link = page.link_with(:text => regexp)
    if link != nil
      link.click
    else
      log "\tCan't find link, probably not logged in."
      log "\tTry deleting #{$passwd} file."
    end
  end

  def goDocRoot(class_page)
    log "Requesting List of folders"
    class_page.link_with(:text => /^Dokumenty/).click
  end

  def lookupFolders(html)
    @extractor.extract_folders(html)
  end

  def processFoldersIntoFiles(folders)
    folders.collect do |folder|
      files = goFiles(folder)
      files_html = files.body
      lookupFiles(files_html).collect do |file|
        entry = { :folder => folder,
          :name => file[:name],
          :href => file[:href]
        }
      end
    end.flatten
  end

  def goFiles(folder)
    log "Requesting Files in folder #{folder[:name]}"
    @agent.get(folder[:href])
  end

  def lookupFiles(html)
    @extractor.extract_files(html)
  end

  def processFiles(files)
    i = 0
    files.each do |file|
      i += 1
      path = "#{@download_dir}/#{file[:folder][:name]}"
      filename = "#{path}/#{file[:name]}"
      log "Processing file #{filename}"

      if !File.exists?(filename)
        log "Downloading to #{filename}"
        log "\t... from #{file[:href]}"
        FileUtils.mkdir_p(path)

        contents = @agent.get_file(file[:href])
        write(filename, contents)
      else
        log "Skipping #{filename}"
        log "\t... file exists"
      end
    end
  end

  def doSaveCookies(filename)
    log "Saving cookies to #{filename}"
    @agent.cookie_jar.save_as(filename)
  end

  def crypt_key
    "WLDNSDvjRBresv4;c6\45869W$#w5tv3[="
  end

  def crypt_file
    $passwd
  end

  def could_not_decrypt
    puts "Login into for #{$baseUrl}"
    l = Readline.readline("Login: ", true)
    p = Readline.readline("Password: ", false)
    { :login => l, :pass => p }
  end
end

def write(file, contents)
  File.open(file, 'w') do |f|
    f.write(contents)
  end
end

puts "Crawling web"
SpoluziaciCrawler.new($downloadlDir).crawl
