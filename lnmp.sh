#!/bin/bash
php_versions="5.6|7.0|7.1|7.2|7.3|7.4"
php_base_packs="fpm|mysql|redis|mbstring|tokenizer|xml|gd"
web_default_user="www-data"
web_default_group="www-data"
default_webhost_dir="/var/www/"

function rand() {
     min=$1
     max=$(($2 - $min + 1))
     num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
     echo $(($num % $max + $min))
}

edit_equal_config() {
     filepath=$1
     var_name=$2
     var_value=$3
     sed -i -e "s|$var_name = .*|$var_name = $var_value|" $filepath
}

edit_nginx_config() {
     filepath=$1
     var_name=$2
     var_value=$3
     sed -i -e "s|$var_name .*;|$var_name  $var_value;|" $filepath
}

#命令所有服务
command_all_server() {
     /etc/init.d/mysql $1
     /etc/init.d/nginx $1
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          /etc/init.d/php$php_version-fpm $1
     done
}

#初始化环境
init_env() {
     echo "Install Base Env"
     apt update && apt upgrade
     apt install sudo git curl vim wget unzip apt-transport-https lsb-release ca-certificates gnupg2 wget -y
}

#初始化PHP
install_php() {
     wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
     sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
     apt update
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          apt install "php$php_version" -y
          for php_base_pack in $(echo $php_base_packs | sed 's/|/ /g'); do
               apt install "php$php_version\-$php_base_pack" -y
          done
     done
}

#初始化Nginx
install_nginx() {
     echo "deb http://nginx.org/packages/debian $(lsb_release -cs) nginx" |
          sudo tee /etc/apt/sources.list.d/nginx.list
     curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
     apt-key fingerprint ABF5BD827BD9BF62
     apt remove apache2 -y
     apt update && apt install nginx -y
}

#初始化Mysql
install_mysql() {
     deb_name="mysql-apt-config_0.8.15-1_all.deb"
     wget "https://repo.mysql.com//$deb_name"
     dpkg -i "./$deb_name" && rm "./$deb_name"
     apt-get update && apt-get install mysql-server -y

}

#初始化Composer
install_composer() {
     php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
     php -r "if (hash_file('sha384', 'composer-setup.php') === 'e0012edf3e80b6978849f5eff0d4b4e4c79ff1609dd1e613307e16318854d24ae64f26d17af3ef0bf7cfb710ca74755a') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
     php composer-setup.php
     php -r "unlink('composer-setup.php');"
     mkdir /usr/share/composer
     mv ./composer.phar /usr/share/composer
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          echo "#!/bin/bash
php$php_version /usr/share/composer/composer.phar
" >/usr/bin/php$php_version-composer
          chmod 755 /usr/bin/php$php_version-composer
          echo "Install Composer Command: php$php_version-composer"
     done
     echo "#!/bin/bash
php /usr/share/composer/composer.phar
" >/usr/bin/composer
     chmod 755 /usr/bin/composer
     echo "Install Composer Command: composer"
}

echo_default_php_nginx_conf_tpl() {
     filepath=$1
     echo "server {
    listen       80;
    server_name  localhost;
    root   /usr/share/nginx/html;

    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.php index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    location ~ \.php$ {
       fastcgi_pass   127.0.0.1:9000;
       fastcgi_index  index.php;
       fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
       include        fastcgi_params;
    }

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}" >$1
}

defaultphp() {
     php_version=$1
     vhostname=$2
     echo "GuGuGU"
}

thinkphp() {
     thinkphp_version=$1
     vhostname=$2
     echo "GuGuGU"
}

laravel() {
     laravel_version=$1
     vhostname=$2
     echo "GuGuGU"
}

gitcode() {
     giturl=$1
     vhostname=$2
     php_version=$3
     web_file_path="$default_webhost_dir$vhostname"
     #Git Clone File
     git clone $giturl $web_file_path
     chown $web_default_user:$web_default_group -R $web_file_path
     #Config Nginx
     nginx_config_path="/etc/nginx/conf.d/$vhostname-php$php_version.conf"
     php_listen_sock="/run/php/php$php_version-fpm.sock"
     echo_default_php_nginx_conf_tpl $nginx_config_path
     port="$(rand 10 655)$(echo "$php_version" | sed "s/\.//g")"
     edit_nginx_config $nginx_config_path "root" $web_file_path
     edit_nginx_config $nginx_config_path "listen" $port
     edit_nginx_config $nginx_config_path "fastcgi_pass" "unix:$php_listen_sock"
     #Reload
     command_all_server reload
     #Echo
     echo "$vhostname PHP-$php_version Listen: 0.0.0.0:$port"
}

import_mysql() {
     sql_file_path=$(realpath $1)
     db_name=$2
     sql_payload="drop database if exists \`$db_name\`;
CREATE DATABASE $db_name DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
use $db_name;
source $sql_file_path;
show tables;"
     mysql -u root -p -e "$sql_payload"
}

#初始化配置Nginx与PHP
init_conf_nginx_php() {
     edit_nginx_config "/etc/nginx/nginx.conf" "user" $web_default_user
     echo '<center><h1>LNMP</h1><center> <?php phpinfo(); ?>' >/var/www/html/index.php
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          #Config PHP-FPM Default
          fpm_filepath="/etc/php/$php_version/fpm/pool.d/www.conf"
          php_listen_sock="/run/php/php$php_version-fpm.sock"
          edit_equal_config $fpm_filepath "listen" $php_listen_sock
          edit_equal_config $fpm_filepath "user" $web_default_user
          edit_equal_config $fpm_filepath "group" $web_default_group
          edit_equal_config "/etc/php/$php_version/fpm/php.ini" "display_errors" "On"
          #Config Nginx Default
          nginx_default_path="/etc/nginx/conf.d/default-php$php_version.conf"
          echo_default_php_nginx_conf_tpl $nginx_default_path
          edit_nginx_config $nginx_default_path "root" "/var/www/html"
          edit_nginx_config $nginx_default_path "listen" $(echo "80$php_version" | sed "s/\.//g")
          edit_nginx_config $nginx_default_path "fastcgi_pass" "unix:$php_listen_sock"
     done
     common_all_server reload
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          echo "Default PHP-$php_version Listen: 0.0.0.0:$(echo "80$php_version" | sed "s/\.//g")"
     done
}
php_mode_install() {
     mod_name=$1
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          apt install php$php_version-$mod_name -y
     done
}

case "$1" in

install)
     echo "Start Install"
     init_env
     echo "Install MySql"
     install_mysql
     echo "Install PHP$php_versions"
     install_php
     echo "Install Nginx"
     install_nginx
     echo "Config Nginx & PHP$php_versions"
     init_conf_nginx_php
     echo "Install Composer"
     install_composer
     echo "Finish Install!"
     ;;
defaultphp)
     defaultphp $2 $3
     ;;

thinkphp)
     thinkphp $2 $3
     ;;
laravel)
     laravel $2 $3
     ;;
gitcode)
     gitcode $2 $3 $4
     ;;
server)
     echo "$2 Server!"
     command_all_server $2
     ;;
php_mode_install)
     php_mode_install $2
     ;;

import_mysql)
     import_mysql $2 $3
     ;;

*)
     echo "$0 install"
     echo "$0 php_mode_install \$mod_name"
     echo "$0 server [start|stop|reload]"
     echo "$0 defaultphp \$php_version \$vhostname"
     echo "$0 thinkphp \$thinkphp_version \$vhostname"
     echo "$0 laravel \$laravel_version \$vhostname"
     echo "$0 gitcode \$giturl \$vhostname \$php_version"
     echo "$0 import_mysql \$sqlfile \$dbname"
     ;;

esac