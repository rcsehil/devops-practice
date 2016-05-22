#!/usr/bin/ruby
require 'aws-sdk'
require 'thor'
require 'net/http'
require 'securerandom'

AWS_CLI_ID = 'AWS_CLI_ID'.freeze
AWS_CLI_SECRET = 'AWS_CLI_SECRET'.freeze
AWS_REGION = 'AWS_REGION'.freeze

# check aws access data
if !ENV.key?(AWS_CLI_ID) || !ENV.key?(AWS_CLI_SECRET) || !ENV.key?(AWS_REGION)
  raise "Set ENV entries: #{AWS_CLI_ID} , #{AWS_CLI_SECRET}, #{AWS_REGION}"
end

Aws.config.update(access_key_id: ENV[AWS_CLI_ID],
                  secret_access_key: ENV[AWS_CLI_SECRET],
                  region: ENV[AWS_REGION])

# Class to get info and interact with AWS EC2 instances and auto scaling groups.
class AwsCli < Thor
  TYPE_INSTANCE_ID = 'Type instance ID:'.freeze
  TYPE_PUBLIC_IP = 'Type public IP:'.freeze
  

  desc 'drupal_status', 'check drupal status'
  method_option :public_ip, desc: 'Specifiy public IP of host where Drupal is running.'
  def drupal_status
    public_ip = get_public_ip(options)
    uri = URI("http://#{public_ip}/drupal/install.php")
    res = Net::HTTP.get_response(uri)
    puts res.body
    puts res.code
  end

  desc 'info', 'get info about instances'
  def info
    ec2 = Aws::EC2::Resource.new

    ec2.instances.each do |i|
      puts "Instance ID: #{i.id}"
      puts "State: #{i.state.name}"
      puts "Public IP: #{i.public_ip_address}"
      puts ''
    end
  end

  desc 'reboot', 'reboots instance named'
  method_option :instance_id, desc: 'Specifiy which instance to start.'
  def reboot
    ec2 = Aws::EC2::Resource.new

    instance_id = get_instance_id(options)

    i = ec2.instance(instance_id)

    if i.exists?
      case i.state.code
      when 48 # terminated
        puts "#{instance_id} is terminated, so you cannot reboot it"
      else
        i.reboot
      end
    end
  end

  desc 'start', 'start instance name'
  method_option :instance_id, desc: 'Specifiy which instance to start.'
  def start
    ec2 = Aws::EC2::Resource.new

    instance_id = get_instance_id(options)

    i = ec2.instance(instance_id)

    if i.exists?
      case i.state.code
      when 0  # pending
        puts "#{instance_id} is pending, so it will be running in a bit"
      when 16  # started
        puts "#{instance_id} is already started"
      when 48  # terminated
        puts "#{instance_id} is terminated, so you cannot start it"
      else
        i.start
      end
    end
  end

  desc 'stop', 'stop instance name'
  method_option :instance_id, desc: 'Specifiy which instance to stop.'
  def stop
    ec2 = Aws::EC2::Resource.new

    instance_id = get_instance_id(options)

    i = ec2.instance(instance_id)

    if i.exists?
      case i.state.code
      when 48  # terminated
        puts "#{instance_id} is terminated, so you cannot stop it"
      when 64  # stopping
        puts "#{instance_id} is stopping, so it will be stopped in a bit"
      when 89  # stopped
        puts "#{instance_id} is already stopped"
      else
        i.stop
        puts "#{instance_id} stop process started"
      end
    end
  end

  desc 'autoscale_info', 'Prints information about autoscaling groups.'
  def autoscale_info
    resource = Aws::AutoScaling::Resource.new
    resource.groups.each do |autoscalinggroup|
      puts "Group name: #{autoscalinggroup.auto_scaling_group_name}"
      puts "Launch config name: #{autoscalinggroup.launch_configuration_name}"
      puts "Min size: #{autoscalinggroup.min_size}"
      puts "Max size: #{autoscalinggroup.max_size}"
      puts "Desired size: #{autoscalinggroup.desired_capacity}"
      puts 'Loadbalancers: '
      autoscalinggroup.load_balancer_names.each do |lb_name|
        puts "  #{lb_name}"
      end
      puts "Attached instances - #{autoscalinggroup.instances.size}: "
      autoscalinggroup.instances.each do |instance|
        puts "  ID: #{instance.id}"
      end
      puts '---'
    end
  end

  no_commands do
    def get_instance_id(options)
      instance_id = options[:instance_id]
      unless instance_id
        info
        puts TYPE_INSTANCE_ID
        instance_id = STDIN.gets.chomp
      end
      instance_id
    end

    def get_public_ip(options)
      public_ip = options[:public_ip]
      unless public_ip
        info
        puts TYPE_PUBLIC_IP
        public_ip = STDIN.gets.chomp
      end
      public_ip
    end
  end
end
AwsCli.start(ARGV)
