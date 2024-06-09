require 'spec_helper'

set :backend, :ssh
set :host, '18.179.174.216'
set :ssh_options, user: 'ec2-user', keys: ['kawakami.pem']

listen_port = 80
rbenv_path = '/home/ec2-user/.rbenv/shims:$PATH'

describe command('ruby -v') do
  let(:path) { rbenv_path }
  its(:stdout) { should match /ruby 3.1.2/ }
end

describe package('rails') do
  let(:path) { rbenv_path }
  it { should be_installed.by('gem').with_version('7.1.3.2') }
end

describe command('node -v') do
  its(:exit_status) { should eq 0 }
end

describe service('nginx') do
  it { should be_running }
end

describe package('unicorn') do
  let(:path) { rbenv_path }
  it { should be_installed.by('gem') }
end

describe file('/etc/nginx/conf.d/rails.conf') do
  it { should be_file }
end

describe port(listen_port) do
  it { should be_listening }
end

describe command("curl http://127.0.0.1:#{listen_port}/ -o /dev/null -w \"%{http_code}\\n\" -s") do
  its(:stdout) { should match /^200$/ }
end
