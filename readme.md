# server install
- curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
- . ~/.nvm/nvm.sh
- nvm install --lts
- sudo cp $(echo "$NVM_DIR/versions/node/$(nvm version)/bin/node") /bin
- sudo yum install git -y -q

### App
npm install -g @socket.io/pm2

#sudo yum install nginx -y
#sudo systemctl start nginx
#sudo systemctl enable  nginx

git clone https://github.com/CodaBool/sockets.git

### PM2
"sudo yum update -y -q",
"sudo grubby --update-kernel=ALL --remove-args=\"systemd.unified_cgroup_hierarchy=0\"",
"curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash",
". ~/.nvm/nvm.sh",
"nvm install --lts",
"npm install --omit=dev",
"sudo yum clean all",
pm2 start sockets.config.cjs
"sudo chmod 750 /tmp/agent.json",
"sudo chown root:root /tmp/agent.json",
"sudo cp /tmp/agent.json /opt/aws/agent.json",
"sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/agent.json",

# Attempt 2
- test connection `curl "https://example.com/socket.io/?EIO=4&transport=polling"`
- find a base ami to manually start `aws ec2 describe-images --owners amazon --filters "Name=architecture,Values=arm64" "Name=name,Values=al2*minimal*" --query "Images | sort_by(@, &CreationDate) | [].[ImageId, Name]" | jq '.[]'`