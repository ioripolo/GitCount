#!/bin/bash
# 统计后台总的提交数、增加、删除、留存代码行数

### 接收时间参数###
Start=$1
End=$2

### 定义分支 ###
if [ ! -n "$3" ] ;then
  Branch=--all
  BranchName=All
else
  Branch=origin/$3
  BranchName=$3-branch
fi

### 当前目录###
if [ $(echo $0 | grep '^/') ]; then
  cur_dir=$(dirname $0)
else
  cur_dir=$(pwd)/$(dirname $0)
fi

### 定义使用文件 ###
## 输入 ##
repo_file=$cur_dir/cdc.txt #版本库定义

## 输出 ##
result_file=$cur_dir/result.txt
:> $result_file

### 删除LineCountResult文件夹 ###
rm -rf $cur_dir/LineCountResult

### 代码提交行数 ###
function CountCodeLines() {
while read git_url
do
  echo $git_url  
  repo_dir=`echo $git_url |awk -F'[/]' '{print $(NF)}'`
  repo_dir=${repo_dir%????}
  
  if [ ! -d "$repo_dir" ]; then
    echo "error: Directory $repo_dir do not exist."
    continue
  fi
  
  cd $repo_dir
  
  echo $Branch
  # 初始化输出文件 #
  mkdir -p $cur_dir/LineCountResult/$repo_dir
  commit_file=$cur_dir/LineCountResult/$repo_dir/$BranchName-commit.txt #提交次数明细
  total_file=$cur_dir/LineCountResult/$repo_dir/$BranchName-total.txt #每人提交次数汇总
  detail_file=$cur_dir/LineCountResult/$repo_dir/$BranchName-detail.txt #每人提交行数明细
  everyone_file=$cur_dir/LineCountResult/$repo_dir/$BranchName-count.txt #每人提交行数信息
  :>$commit_file
  :>$detail_file
  :>$total_file
  :>$everyone_file
  
  # 计算开始 #
  git pull
  git log --pretty='%aN' --since=$Start --until=$End --no-merges $Branch -- | sort | uniq -c | sort -k1 -n -r >> $commit_file
  # 统计各版本总行数
  git log --author=^.* --pretty=tformat: --numstat --since=$Start --until=$End --no-merges $Branch -- |\
  awk '{ add += $1 ; subs += $2 ; loc += $1 - $2 } \
  END { print add,subs,loc ,repo_name }' repo_name=$repo_dir - >> $detail_file
  
  ### 计算总提交次数
  awk '{sum[$2]+=$1}END{for(i in sum)print i ,sum[i]}' $commit_file |sort -k2 -nr > $total_file
  
  # 记录各人代码、增加行数、删除行数明细
  git log --pretty='tformat:%aN' --numstat --since=$Start --until=$End --no-merges $Branch -- >>$everyone_file
  
  cat $everyone_file >> $result_file
  cd ../
done < $repo_file
}

#awk '{sum[$2]+=$1}END{for(i in sum)print i ,sum[i]}' scrope.txt |sort -k2 -nr >

CountCodeLines
### 汇总计算各人的代码行数
### 删除空行
awk '!/^$/' $result_file |\
### 计算
awk '{if(NF==1){if(NR!=1){printf"\n%20s%8d%8d",name,adds,dels;adds=0;dels=0}name=$1}else{adds=adds+$1;dels=dels+$2;next}}END{printf"\n%20s%8d%8d",name,adds,dels;adds=0;dels=0}'|\
### 汇总
awk '{cnt[$1]++;name[$1]=$1;adds[$1]+=$2;dels[$1]+=$3}END{for(i in name) printf "%-20s%10d%10d%10d%10d\n", name[i],cnt[i],adds[i],dels[i],adds[i]-dels[i]}'
