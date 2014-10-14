include_recipe "sprout-osx-base::homebrew"

run_unless_marker_file_exists("nginx") do

  execute "uninstall nginx" do
    only_if "brew list | grep nginx"
    command "sudo brew remove nginx"
  end

  brew "nginx"

  plist_paths = [
    File.join('', 'Library', 'LaunchDaemons'),
    File.join('~', 'Library', 'LaunchAgents'),
  ].map { |path| File.expand_path('org.nginx.nginx.plist', path) }

  root_plist_path = plist_paths.first

  plist_paths.each do |plist_path|
    if File.exists?(plist_path)
      log "nginx plist found at #{plist_path}"
      execute "unload the plist (shuts down the daemon)" do
        command %'launchctl unload -w #{plist_path}'
        user "root"
      end
    else
      log "Did not find plist at #{plist_path} don't try to unload it"
    end
  end

  directory File.dirname(root_plist_path) do
    action :create
    recursive true
    owner 'root'
  end

  template root_plist_path do
    source "org.nginx.nginx.plist.erb"
    owner "root"
  end

  execute "start the daemon" do
    command %'sudo launchctl load -w #{root_plist_path}'
  end
end

template "/usr/local/etc/nginx/nginx.conf" do
  source "nginx.conf.erb"
  cookbook node['nginx_settings']['conf_template_cookbook'] || @cookbook_name.to_s
  owner node['current_user']
end

execute "reload the configuration" do
  command "sudo nginx -s reload"
end
