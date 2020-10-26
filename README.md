## tunnel-setup
Tool for setuping GRE/IPIP tunnel between client's server and Cloud-Shield network.

[Cloud-Shield.ru](https://cloud-shield.ru) provides DDoS protection for remote servers, services and web sites.


You should have an active product for using this script.

You can get a Secret **KEY** at the product details page on our site.

## Requirements
```
curl wget traceroute jq
```

## Installation
```Shell
wget https://raw.githubusercontent.com/cloud-shield/tunnel-setup/master/setup.sh -O setup.sh
chmod +x setup.sh
./setup.sh install your_secret_key_here
```

## Usage
```
systemctl start cstunnel
systemctl stop cstunnel
```

## TODO

- [ ] One line code installer
- [ ] Additional protected IPs support
- [x] CentOS (yum) compatibility
- [ ] CI tests for different system types
- [ ] better exception handling in tun_up func
- [ ] tunnel self test (health & etc)
- [ ] ability to set params via CLI
- [ ] setup.sh auto update
