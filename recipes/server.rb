include_recipe "teamcity::common"

template "#{node["teamcity_server"]["root_dir"]}/conf/server.xml" do
  source "server.xml.erb"
  owner  node["teamcity_server"]["user"]
  group  node["teamcity_server"]["group"]
  variables(
    :address => node["teamcity_server"]["server"]["address"],
    :port    => node["teamcity_server"]["server"]["port"],
    :path => node["teamcity_server"]["server"]["path"],
    :docbase => node["teamcity_server"]["root_dir"]
  )
end

template "#{node["teamcity_server"]["data_dir"]}/config/database.properties" do
  source "database.properties.erb"
  owner  node["teamcity_server"]["user"]
  group  node["teamcity_server"]["group"]
  variables(
    :database_connection_url => node["teamcity_server"]["server"]["database_connection_url"],
    :database_user => node["teamcity_server"]["server"]["database_user"],
    :database_pass => node["teamcity_server"]["server"]["database_pass"]
  )
  only_if { node["teamcity_server"]["server"]["database_internal"] == false }
end

# Install upstart file
template "/etc/init/teamcity-server.conf" do
  source "upstart/teamcity-server.erb"
  owner  "root"
  group  "root"
  variables(
      :user => node["teamcity_server"]["user"],
      :group => node["teamcity_server"]["group"],
      :data_dir => node["teamcity_server"]["data_dir"],
      :root_dir => node["teamcity_server"]["root_dir"]
  )
end

directory "#{node["teamcity_server"]["data_dir"]}/lib/jdbc" do
  owner  node["teamcity_server"]["user"]
  group  node["teamcity_server"]["group"]
  mode "0755"
  action :create
end

if node['teamcity_server']['server']['jdbc_driver_url']
  basename = node['teamcity_server']['server']['jdbc_driver_url'].split('/').last
  jdbc_path = "#{node["teamcity_server"]["data_dir"]}/lib/jdbc/#{basename}"

  remote_file jdbc_path do
    source node['teamcity_server']['server']['jdbc_driver_url']
    action :create_if_missing
    only_if {node['teamcity_server']['server']['jdbc_driver_url']}
  end
end
