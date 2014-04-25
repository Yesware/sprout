brew "heroku-toolbelt"

node['heroku_toolbelt']['plugins'].each do |plugin|
  execute "installing #{plugin} heroku toolbelt plugin" do
    command "heroku plugins:install git://github.com/heroku/heroku-#{plugin}.git"
    user node['current_user']
  end
end
