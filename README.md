# Magentify

[Capistrano](http://capify.org) is an open source tool for executing commands on multiple servers in parallel. It is intended to be used to easily deploying applications. While it was built specifically for deploying Rails apps, it is designed to be easily extended to deploy any type of application or run any number of commands. This project is a deployment recipes collection that works specifically with [Magento](http://www.magentocommerce.com/).

## Installation

    $ gem install magentify
    
## Project setup

    $ magentify .

## Usage

Once you have run `magentify` on your project it will add a Capfile and deploy.rb configuration file

```ruby
set :application, "magento"
set :domain,      "#{application}.com"
set :deploy_to,   "/var/www/#{domain}"

set :user,        "deploy"
set :repository,  "git@github.com:user/project.git"
set :scm,         :git

role :web,        "000.000.000.000"   # Your HTTP server, Apache/etc
role :app,        "000.000.000.000"   # This may be the same as your `Web` server or a separate administration server

set  :keep_releases,  3

set :mage_base, ""   # If Magento is installed in a sub-directory you can configure it here, for example "/shop"

set :app_symlinks, ["/media", "/var", "/sitemaps", "/staging"]
set :app_shared_dirs, ["/app/etc", "/sitemaps", "/media", "/var", "/staging"]
set :app_shared_files, ["/app/etc/local.xml"]
```

Once you have magentified your project you can run:

    $ cap -T
    
This will list all the available tasks that can be run with a shot description. For more detailed information about each of the tests run:

    $ cap -e [task_name]
    
For detailed information about how to configure and use Capistrano for deployment you should read the Capistrano wiki pages:

* [Getting Started](https://github.com/capistrano/capistrano/wiki/2.x-Getting-Started)
* [From the beginning](https://github.com/capistrano/capistrano/wiki/2.x-From-The-Beginning)

## Contributing

1. [Fork it](https://github.com/alistairstead/Magentify/fork_select)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Create a cucumber scenario to describe your feature
4. Add the steps to test the functionality
5. Add your Feature or Fix to satisfy the tests.
6. Commit your changes (`git commit -am 'Added some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create new Pull Request
