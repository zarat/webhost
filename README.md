# webhost

Your domain (www, *) should already point to your server.

<pre>
# example dns setup
*      IN    CNAME    your.domain
</pre>

<pre>
# clone repository
apt update && apt install -y git && git clone https://github.com/zarat/webhost && cd webhost && bash init.sh
</pre>

<pre>
# add a vhost "test" (test.your.domain)
bash create-vhost.sh test
</pre>
