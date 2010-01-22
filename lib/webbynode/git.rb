module Webbynode
  class GitError < StandardError; end
  class GitNotRepoError < StandardError; end
  class GitRemoteDoesNotExistError < StandardError; end
  class GitRemoteAlreadyExistsError < StandardError; end

  class Git
    
    attr_accessor :config, :remote_ip
    
    def present?
      io.directory?(".git")
    end
    
    def init
      exec("git init") do |output|
        # this indicates init was properly executed
        output =~ /^Initialized empty Git repository in/
      end
    end
    
    def add(what)
      exec "git add #{what}"
    end
    
    def add_remote(name, host, repo)
      exec("git remote add #{name} git@#{host}:#{repo}") do |output|
        # raise an exception if remote already exists
        raise GitRemoteAlreadyExistsError, output if output =~ /remote \w+ already exists/
        
        # success if output is empty
        output.nil? or output.empty?
      end
    end
    
    def commit(comments)
      comments.gsub! /"/, '\"'
      exec("git commit -m \"#{comments}\"")
    end

    def parse_config
      return @config if defined?(@config)
      if present? and remote_webbynode?
        config = {}
        current = {}
        File.open(".git/config").each_line do |line|
          case line
          when /^\[(\w+)(?: "(.+)")*\]/
            key, subkey = $1, $2
            current = (config[key] ||= {})
            current = (current[subkey] ||= {}) if subkey
          else
            key, value = line.strip.split(' = ')
            current[key] = value
          end
        end
        @config = config
      else
        raise Webbynode::GitNotRepoError, "Git repository does not exist." unless present?
        raise Webbynode::GitRemoteDoesNotExistError, "Webbynode has not been initialized." unless remote_webbynode?
      end
    end
    
    def parse_remote_ip
      @config     ||= parse_config
      @remote_ip  ||= ($2 if @config["remote"]["webbynode"]["url"] =~ /^(\w+)@(.+):(.+)$/) if @config
    end
    
    def remote_webbynode?
      return true if io.exec('git remote') =~ /webbynode/
      false 
    end
    
    private
    
      def exec(cmd, &blk)
        handle_output io.exec(cmd), &blk
      end
    
      def handle_output(output, &blk)
        raise GitNotRepoError, output if output =~ /Not a git repository/

        if blk
          raise GitError, output unless blk.call(output)
        else
          raise GitError, output unless output.nil? or output.empty?
        end
      
        true
      end
    
  end
end
