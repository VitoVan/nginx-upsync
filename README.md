![Nginx Upsync Icon](https://github.com/VitoVan/nginx-upsync/raw/master/iconfile.png)

# nginx-upsync

Docker Image for nginx-upsync-module and nginx-stream-upsync-module

This image enabled two more modules beyond [Nginx Offical Mainline Alpine Image](https://github.com/nginxinc/docker-nginx/blob/a973c221f6cedede4dab3ab36d18240c4d3e3d74/mainline/alpine/Dockerfile):

- [nginx-upsync-module](https://github.com/weibocom/nginx-upsync-module)

- [nginx-stream-upsync-module](https://github.com/xiaokai-wang/nginx-stream-upsync-module)

## How to use

> Demostration only, for more useage, please refer to the module repo(s).

1. Prepare nginx-upsync.conf

    File: `nginx-demo.conf`

    ```nginx
    events { }

    http {
        upstream demo {
            least_conn;
            upsync 127.0.0.1:8500/v1/health/service/demo upsync_timeout=6m upsync_interval=500ms upsync_type=consul_health strong_dependency=off;
            upsync_dump_path /etc/nginx/conf.d/demo.conf;
            upsync_lb least_conn;
            include /etc/nginx/conf.d/demo.conf;
        }

        server {
            location = /demo {
                proxy_pass http://demo;
            }
            location = /upstream_show {
                upstream_show;
            }
        }
    }
    ```

2. Prepare nginx-demo.conf

    File: `nginx-demo.conf`

    ```nginx
    server 127.0.0.1:9527 weight=1 max_fails=1 fail_timeout=1s;
    ```

3. Run

    ```bash
    docker run -d --net dc-a --name nginx \
       -v `pwd`/nginx-upsync.conf:/etc/nginx/nginx.conf \
       -v `pwd`/nginx-demo.conf:/etc/nginx/conf.d/demo.conf \
       -p 9000:80 \
       vitovan/nginx-upsync:1.17.6
    ```
