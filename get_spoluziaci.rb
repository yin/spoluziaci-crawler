$LOAD_PATH.unshift "."

require 'config'
require 'rubygems'

#require 'pp'
require 'mechanize'
require 'nokogiri'
require 'logger'
require 'readline'
require 'lib/aes_crypter'
require 'lib/link_extractor'
require 'lib/my_logger'

class SpoluziaciCrawler
  include MyLogger
  include AESCrypter
  def initialize(download_dir)
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Linux Firefox'
    @agent.follow_meta_refresh = true
    @agent.redirect_ok = true
    @agent.log = Logger.new $mechanizeLog

    if $proxy_use
      params = ['proxy.rwe.com', '8080']
      params << $proxy_user << $proxy_pass if $proxy_user && $proxy_pass
      log "Setting proxy to: #{params}"
      @agent.set_proxy *params
    else
      log "Not using any proxy..."
    end

    @extractor = DocumentLinkExtractor.new
    @download_dir = download_dir
  end

  def crawl
    begin
      account = doLogin
    rescue Net::HTTPProxyAuthenticationRequired
      log "Proxy authentication needed..."
    end

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
    homepage = goHomepage
    log "Logging out"
    goLinkRegex homepage, $logout_link_regexp
  end

  def goHomepage
    log "Requesting Homepage: #{$baseUrl}"
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
    with_redirects false do
      files_skip, files_download = files.partition do |file|
        filename, path = filename_and_path(file)
        File.exists?(filename)
      end

      files_skip.each do |file|
        log "Skipping: #{file[:folder][:name]}/#{file[:name]}"
      end

      files_download.each do |file|
        download_file file
      end
    end
  end

  def download_file(file)
    begin
      filename, path = filename_and_path(file)
      log "Processing file #{filename}"

      if !File.exists?(filename)
        log "Downloading to #{filename}"
        log "\t... from #{file[:href]}"
        FileUtils.mkdir_p(path)

        contents = @agent.get_file(file[:href])
        write(filename, contents)
      end
    rescue BasicObject => e
      log "Error while downloading #{file[:name]}: #{e}"
    end
  end

  def with_redirects(redirect_ok, &block)
    old_redirect_ok = @agent.redirect_ok
    old_meta_refresh = @agent.follow_meta_refresh
    @agent.redirect_ok = redirect_ok
    @agent.follow_meta_refresh = redirect_ok
    yield
    @agent.redirect_ok = old_redirect_ok
    @agent.follow_meta_refresh = old_meta_refresh
  end

  def filename_and_path(file)
    path = "#{@download_dir}/#{file[:folder][:name]}"
    filename = "#{path}/#{file[:name]}"
    return filename, path
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
