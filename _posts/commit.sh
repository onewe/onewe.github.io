#!/bin/bash
sed -i '' 's/cover: .\/img/cover: https:\/\/gitee.com\/oneww\/onew_image\/raw\/master/g' $1
sed -i '' 's/!\[image\](.\/img/!\[images\](https:\/\/gitee.com\/oneww\/onew_image\/raw\/master/g' $1
git add $1
git commit -m "$2"
git push origin master
cd ./img
git add .
git commit -m "$2"
git push origin master
cd ..
scp `pwd`/$1 v2ray:/www/source/_posts
ssh v2ray sh /www/deploy.sh
exit 0
