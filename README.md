# webhost

Your domain (www, *) should already point to your server.

<pre>
# example dns setup
.      IN    A     1.2.3.4
www    IN    CNAME your.domain
*      IN    CNAME www.your.domain
</pre>

<pre>
# clone repository
apt update && apt install -y git && git clone https://github.com/zarat/webhost
</pre>

<pre>
# initialize repository
cd webhost
bash init.sh
</pre>

<pre>
# add a vhost "test" (test.your.domain)
bash create-vhost.sh test
</pre>
