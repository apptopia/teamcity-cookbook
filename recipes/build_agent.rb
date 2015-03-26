include_recipe "teamcity::common"

# Create agents directory
directory "#{node["teamcity_server"]["root_dir"]}/agents" do
  user  node["teamcity_server"]["user"]
  group  node["teamcity_server"]["group"]
end

# Convert attributes to hash for easier parsing
agent_defaults = JSON.parse(node["teamcity_server"]["build_agent"].to_json)

agents = if node["teamcity_server"]["build_agents"].nil?
  # If necessary, create a build_agents entry.
  { "buildAgent" => agent_defaults }
else
  # Convert attributes to hash for easier parsing
  JSON.parse(node["teamcity_server"]["build_agents"].to_json)
end
port = 9090
agents.each do |agent, p|
  properties          = agent_defaults.merge(p)
  properties_file     = "#{node["teamcity_server"]["root_dir"]}/agents/#{agent}/conf/buildAgent.properties"
  own_address         = node["ipaddress"]
  authorization_token = nil

  if File.exists?(properties_file)
    lines = File.readlines(properties_file).grep(/^authorizationToken=/)

    unless lines.empty?
      match = /authorizationToken=([0-9a-f]+)/.match(lines.first)
      authorization_token = match[1] if match
    end

    unless properties["name"]
      lines = File.readlines(properties_file).grep(/^name=/)

      unless lines.empty?
        match = /name=(.+)/.match(lines.first)
        properties["name"] = match[1].strip if match
      end
    end
  end

  execute "copy_buildAgent_to_#{agent}" do
    command "cp -Rf #{node["teamcity_server"]["root_dir"]}/buildAgent #{node["teamcity_server"]["root_dir"]}/agents/#{agent}"
    user node["teamcity_server"]["user"]
    group node["teamcity_server"]["group"]
    not_if { File.directory?("#{node["teamcity_server"]["root_dir"]}/agents/#{agent}") }
  end

  template properties_file do
    source "buildAgent.properties.erb"
    owner  node["teamcity_server"]["user"]
    group  node["teamcity_server"]["group"]
    variables(
      :server_url          => properties["server_url"] || node["teamcity_server"]["server_url"],
      :name                => properties["name"] || agent,
      :own_address         => own_address,
      :port                => properties["port"] || port,
      :authorization_token => authorization_token,
      :blank_properties    => properties["blank_properties"],
    )
  end

  port += 1
end


# Install upstart file
template "/etc/init/teamcity-agent.conf" do
  source "upstart/teamcity-agent.erb"
  owner  "root"
  group  "root"
  variables(
      :user => node["teamcity_server"]["user"],
      :group => node["teamcity_server"]["group"],
      :data_dir => node["teamcity_server"]["data_dir"],
      :root_dir => node["teamcity_server"]["root_dir"],
      :rbenv_root => node["teamcity_server"]["build_agent"]["rbenv_root"],
  )
end
