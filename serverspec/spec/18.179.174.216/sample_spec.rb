require 'spec_helper'

set :backend, :ssh
set :host, '18.179.174.216'
set :ssh_options, :user => 'ec2-user', :keys => ['kawakami.pem']

listen_port = 80

describe command('ruby -v') do
  let(:path) { '/home/ec2-user/.rbenv/shims:$PATH' }
  its(:stdout) { should match /ruby 3.1.2/ }
end

describe package('bundler') do
  let(:path) { '/home/ec2-user/.rbenv/shims:$PATH' }
  it { should be_installed.by('gem').with_version('2.3.14') }
end

describe package('rails') do
  let(:path) { '/home/ec2-user/.rbenv/shims:$PATH' }
  it { should be_installed.by('gem').with_version('7.0.4') }
end

describe command('node -v') do
  let(:path) { '/home/ec2-user/.rbenv/shims:$PATH' }
  its(:exit_status) { should eq 0 }
end

describe command('yarn -v') do
  let(:path) { '/home/ec2-user/.rbenv/shims:$PATH' }
  its(:exit_status) { should eq 0 }
end

describe package('nginx') do
  it { should be_installed }
end

describe service('nginx') do
  it { should be_running }
end

describe package('unicorn') do
  let(:path) { '/home/ec2-user/.rbenv/shims:$PATH' }
  it { should be_installed.by('gem') }
end

describe file('/etc/nginx/conf.d/rails.conf') do
  it { should be_file }
end

describe port(listen_port) do
  it { should be_listening }
end

describe command('curl http://127.0.0.1:#{listen_port}/ -o /dev/null -w "%{http_code}\n" -s') do
  its(:stdout) { should match /^200$/ }
end

describe 'SSH connection' do
  it 'should connect to the remote host' do
    Net::SSH.start('18.179.174.216', 'ec2-user', keys: ['kawakami.pem']) do |ssh|
      # ここにSSH接続が成功した場合のテストコードを記述する
      # 例えば、特定のコマンドを実行して結果を検証するなど
    end
  end
end
