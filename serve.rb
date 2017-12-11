require 'bundler'
Bundler.require
require 'securerandom'
require 'sinatra/custom_logger'
require 'logger'
require 'benchmark'
require 'open3'


# Wait for new command request to be executed
post '/' do
  logger.debug 'Request for command execution'
  return 403 unless can_process_cmd?
  send_mail_validation
end


# Validate token for command execution
get '/:token' do
  return 403 unless verify_token(params[:token])
  # Unlock thread for execution
  settings.queue << 1
  logger.debug 'Thread unlocked for command execution'
end

private 

  # Validates new request can be initiated. This means that:
  #   * There is no command executing just now
  def can_process_cmd?
    settings.queue.empty?
  end

  # Generates a new secure token for future validation
  def generate_token
    SecureRandom.urlsafe_base64.tap do |token|
      logger.debug "Generated token #{token}"
    end
  end

  def self.initialize_command_thread(settings)
    settings.logger.debug "Loaded with environments:\n" + ENV.map{|k,v| "  #{k}=#{v}"}.join("\n")
    Thread.abort_on_exception = true
    Thread.new do
      loop do
        settings.logger.info "Waiting for command execution..."
        settings.cache[:token] = nil #invalidates this token
        settings.logger.info "Start command execution"
        cmd = "#{settings.cmd} #{settings.cache[:args]}"
        settings.logger.debug "Will execute #{cmd}"
        stdout_str, stderr_str, status = nil
        time = Benchmark.measure do 
          stdout_str, stderr_str, status = Open3.capture3(ENV,cmd)
        end
        settings.queue.pop
        subject = (status.success? ? "SUCCESS" : "ERROR") +  " executing #{cmd}"
        Mail.deliver do
          from     settings.mail_from
          to       settings.mail_to
          subject  subject
          body  <<-BODY
Command runs in #{time.real} seconds

-------------------------------------------------------------------------------

Errors
======
#{stderr_str}


Output
======
#{stdout_str}
          BODY
          end
        end
        settings.logger.info "Command executed"
      end
  end

  def process_cmd_request
    if settings.cache[:ts].nil? ||
       settings.cache[:token].nil? ||
       Time.now - settings.cache[:ts] > settings.cache_timeout ||
       %w(true 1).include?(params[:force])
      settings.cache[:ts] = Time.now
      settings.cache[:token] = generate_token
      settings.cache[:args] = params[:args]
    end
    return settings.cache[:token], settings.cache[:args]
  end

  def verify_token(token)
    settings.cache[:ts] &&
      settings.cache[:token] &&
      Time.now() - settings.cache[:ts] < settings.cache_timeout &&
      settings.cache[:token] == token
  end

  def send_mail_validation
    token, args = process_cmd_request
    token_url = uri("/#{token}", true)
    html_body = erb(:mail, locals: {token_url: token_url, cmd: settings.cmd, args: args})
    text_body = erb(:mail_txt, locals: {token_url: token_url, cmd: settings.cmd, args: args})
    app = self
    Mail.deliver do
      from     app.settings.mail_from
      to       app.settings.mail_to
      subject  app.settings.mail_subject
      html_part do
        content_type 'text/html; charset=UTF-8'
        body html_body
      end
      text_part do
        body text_body
      end
    end
  end

configure do
  set :logger, Logger.new(STDOUT)
  set :cmd, ENV['CMD_AS'] || 'echo "Hello World"'
  set :mail_to, ENV['MAIL_TO'] || 'user@example.net'
  set :mail_from , ENV['MAIL_FROM'] || 'cmd_as_service@example.net'
  set :mail_subject, ENV['MAIL_SUBJECT'] || 'Command as a service'
  set :cache, Hash.new
  set :cache_timeout, (ENV['CACHE_TIMEOUT'] || '300').to_i # Number of seconds till cache is valid
  set :queue, SizedQueue.new(1)
  enable :logging

  initialize_command_thread settings 

  Mail.defaults do
    delivery_method :smtp, {
      address:        ENV['MAIL_HOST'] || 'mail.example.net', 
      port:           ENV['MAIL_PORT'] || '25',
      user_name:      ENV['MAIL_USER'],
      password:       ENV['MAIL_PASS'],
      authentication: ENV['MAIL_AUTH'],   # :plain, :login, :cram_md5, the default is no auth
      enable_starttls_auto: !(ENV['MAIL_STARTTLS'].nil? || ENV['MAIL_STARTTLS'].empty?)
    }
  end
end
