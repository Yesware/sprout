include_recipe "sprout-osx-base::homebrew"

formula_name = "postgresql#{node['postgres']['version']}"
plist_name = "homebrew.mxcl.postgresql.plist"
versioned_plist_name = "homebrew.mxcl.#{formula_name}.plist"

run_unless_marker_file_exists("postgres") do

  [plist_name, "org.postgresql.postgres.plist" ].each do |plist|
    plist_path = File.expand_path(plist, File.join('~', 'Library', 'LaunchAgents'))
    if File.exists?(plist_path)
      log "postgres plist found at #{plist_path}"
      execute "unload the plist (shuts down the daemon)" do
        command %'launchctl unload -w #{plist_path}'
        user node['current_user']
      end
    else
      log "Did not find plist at #{plist_path} don't try to unload it"
    end
  end

# blow away default image's data directory
  directory "/usr/local/var/postgres" do
    action :delete
    recursive true
  end

  brew formula_name

  execute "create the database cluster" do
    command "/usr/local/bin/initdb --encoding=utf8 --locale=en_US /usr/local/var/postgres"
    user node['current_user']
  end

  launch_agents_path = File.expand_path('.', File.join('~','Library', 'LaunchAgents'))
  directory launch_agents_path do
    action :create
    recursive true
    owner node['current_user']
  end


  execute "copy over the plist" do
    command %'cp /usr/local/Cellar/#{formula_name}/9.*/#{versioned_plist_name} ~/Library/LaunchAgents/#{plist_name}'
    user node['current_user']
  end

  execute "start the daemon" do
    command %'launchctl load -w ~/Library/LaunchAgents/#{plist_name}'
    user node['current_user']
  end

  ruby_block "wait four seconds for the database to start" do
    block do
      sleep 4
    end
  end

  execute "create the 'postgres' user" do
    command "/usr/local/bin/createuser --createdb --no-superuser --no-createrole postgres"
    user node['current_user']
  end

  (node['postgres']['databases'] || ['']).each do |db_name|
    execute "create the #{db_name} database" do
      command "/usr/local/bin/createdb -O postgres #{db_name}"
      user node['current_user']
    end
  end
  # "initdb /tmp/junk.$$" will fail unless you modify sysctl variables
  # Michael Sofaer says that these are probably the right settings:
  #   kern.sysv.shmall=65535
  #   kern.sysv.shmmax=16777216

  log "Make sure /usr/local/bin comes first in your PATH, else you will invoke the wrong psql and error with '...Domain socket \"/var/pgsql_socket/.s.PGSQL.5432\""
end

ruby_block "test to see if postgres is running" do
  block do
    require 'socket'
    postgres_port = 5432
    begin
      s = TCPSocket.open('localhost',postgres_port)
    rescue => e
      raise "postgres is not running: " << e.message
    end
    s.close
    `sudo -u #{node['current_user']} /usr/local/bin/psql -U postgres < /dev/null`
    if $?.to_i != 0
      raise "I couldn't invoke postgres!"
    end
  end
end
