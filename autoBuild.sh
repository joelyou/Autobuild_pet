#! /bin/bash
# 调用方式：bash autoBuild.sh debug
# debug代表测试服， release代表正式服
 
# 正式服 测试服 默认测试服
production_environment=$1

# 编译配置文件
build_config_plist=~/Desktop/project/Pet/buildConfig.plist


if test $production_environment != "release"
then
production_environment="debug"
GCC_PREPROCESSOR_DEFINITIONS="COCOAPODS=1 SD_WEBP=1"

build_num_key="build_debug_num"
build_date_key="build_debug_date"

else
GCC_PREPROCESSOR_DEFINITIONS="PET_PRODUCTION_ENVIRONMENT=1 COCOAPODS=1 SD_WEBP=1"

build_num_key="build_num"
build_date_key="build_date"

fi

# build号  我们是使用当前时间+当天打包索引(170302 + 01)
# 上一次编译时间
build_last_number=$(/usr/libexec/PlistBuddy -c "print ${build_num_key}" ${build_config_plist})
build_last_date=$(/usr/libexec/PlistBuddy -c "print ${build_date_key}" ${build_config_plist})

build_date=$(date +%y%m%d)
build_number=1

if test $build_last_date == $build_date
then
build_number=$(($build_last_number+1))
else
build_number=1
fi

# 合成build number string
build_number_string=${build_date}$(printf "%02d" "$build_number")

echo ================ 打包日期：$(date +%Y-%m-%d\ %H:%S) build_number:${build_number_string} production_environment:${production_environment} =============


# 工程环境路径
workspace_path=~/Projects/PetWorkspace/Pet
# info.plist文件的位置
info_plist=${workspace_path}/Pet/Info.plist

# 进入要工作的文件夹
cd ${workspace_path}

# 去svn上拉取最新的代码 
svn update

# 修改build号
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number_string" ${info_plist}

# 获取版本号
build_version=$(/usr/libexec/PlistBuddy -c "print CFBundleShortVersionString" ${info_plist})

echo ================ 版本信息： build_version:${build_version} build_number:${build_number_string} =============

# workspace name
workspace_name=Pet
 
# 打包项目名字
scheme_name=Pet
 
# 指定build文件夹的位置
archive_base_path=~/Desktop/project/Pet

# 指定归档路径
archive_name=${build_version}_${build_number_string}.xcarchive
archive_dev_path=${archive_base_path}/archive/archive_dev/Pet_dev_${archive_name}
archive_hoc_path=${archive_base_path}/archive/archive_hoc/Pet_hoc_${archive_name}

if test $production_environment == "release"
then
archive_path=${archive_hoc_path}
svn_ipa_path=svn://liyangy@192.168.24.251/project/test/ios%E4%B8%93%E7%94%A8/%E6%AD%A3%E5%BC%8F%E6%9C%8D/%E6%9C%89%E5%AE%A0/${build_version}/Pet_hoc_${build_number_string}.ipa
else
archive_path=${archive_dev_path}
svn_ipa_path=svn://liyangy@192.168.24.251/project/test/ios%E4%B8%93%E7%94%A8/%E6%B5%8B%E8%AF%95%E6%9C%8D/%E6%9C%89%E5%AE%A0/${build_version}/Pet_dev_${build_number_string}.ipa
fi

# 指定ipa的输出位置
ipa_name=${build_version}_${build_number_string}.ipa
ipa_temp_name=${scheme_name}.ipa
ipa_temp_path=${archive_base_path}/ipa/ipa_temp
ipa_dev_path=${archive_base_path}/ipa/ipa_dev/Pet_dev_${ipa_name}
ipa_hoc_path=${archive_base_path}/ipa/ipa_hoc/Pet_hoc_${ipa_name}
ipa_dis_path=${archive_base_path}/ipa/ipa_dis/Pet_dis_${ipa_name}

# exportOptionsPlist文件位置
export_options_plist_path=${archive_base_path}/exportOptionsPlist
 

# 清除
echo ================ Clean project =============
# xcodebuild clean
 
# 生成在archive_path路径下面
echo ================ 开始归档 =============
xcodebuild archive -workspace ${workspace_name}.xcworkspace GCC_PREPROCESSOR_DEFINITIONS="${GCC_PREPROCESSOR_DEFINITIONS}" -scheme ${scheme_name} -configuration Release -archivePath ${archive_path}

#检查文件是否存在
if [ -d ${archive_path} ];
then
echo "归档成功: ${archive_path}"
else
echo "归档失败."
exit 1
fi

# 根据环境打包
if test $production_environment == "release"
then
echo ================ 开始生成hoc包 =============
# xcodebuild -exportArchive -archivePath ${archive_path} -exportPath ${ipa_hoc_path} -exportFormat IPA -exportProvisioningProfile yourpet_hoc
xcodebuild -exportArchive -archivePath ${archive_path} -exportPath ${ipa_temp_path} -exportOptionsPlist ${export_options_plist_path}/AdHocExportOptions.plist
mv ${ipa_temp_path}/${ipa_temp_name} ${ipa_hoc_path}


echo ================ 开始生成dis包 =============
# xcodebuild -exportArchive -archivePath ${archive_path} -exportPath ${ipa_dis_path} -exportFormat IPA -exportProvisioningProfile yourpet_dis
xcodebuild -exportArchive -archivePath ${archive_path} -exportPath ${ipa_temp_path} -exportOptionsPlist ${export_options_plist_path}/AppStoreExportOptions.plist
mv ${ipa_temp_path}/${ipa_temp_name} ${ipa_dis_path}

#检查文件是否存在
if [ -f ${ipa_hoc_path} ];
then
echo "打包成功: ${ipa_hoc_path}"
#上传到svn服务器
svn import ${ipa_hoc_path} ${svn_ipa_path} -m "${ipa_name}"
#上传到fir服务器
fir publish ${ipa_hoc_path} -c "正式服 Pet_hoc_${ipa_name}"
else
echo "打包失败."
exit 1
fi

else

echo ================ 开始生成dev包 =============
# xcodebuild -exportArchive -archivePath ${archive_path} -exportPath ${ipa_dev_path} -exportFormat IPA -exportProvisioningProfile yourpet_dev
xcodebuild -exportArchive -archivePath ${archive_path} -exportOptionsPlist ${export_options_plist_path}/AppDevExportOptions.plist -exportPath ${ipa_temp_path}
mv ${ipa_temp_path}/${ipa_temp_name} ${ipa_dev_path}

#检查文件是否存在
if [ -f ${ipa_dev_path} ];
then
echo "打包成功: ${ipa_dev_path}"
#上传到svn服务器
svn import ${ipa_dev_path} ${svn_ipa_path} -m "${ipa_name}"
#上传到fir服务器
fir publish ${ipa_dev_path} -c "测试服 Pet_dev_${ipa_name}"
else
echo "打包失败."
exit 1
fi

fi

# 修改打包日期和打包版本号
/usr/libexec/PlistBuddy -c "Set :${build_num_key} ${build_number}" ${build_config_plist}
/usr/libexec/PlistBuddy -c "Set :${build_date_key} ${build_date}" ${build_config_plist}

echo "修改打包日期和打包版本号 成功"

