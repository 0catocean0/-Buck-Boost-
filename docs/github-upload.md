# 上传GitHub

## 网页上传

1. 在GitHub创建空仓库，例如buck-boost-course-project。首次可设为Private，核对后再改公开。
2. 不自动生成另一份README。将本目录**内部文件和子目录**上传到仓库根目录，不上传外层ZIP本身。
3. 提交后确认README中的图片、文件链接可打开。
4. 作者自行选择是否增加许可证；本目录没有预设开源授权。

## Git命令

在本目录打开终端。把下方占位仓库地址换成自己新建仓库的真实地址：

```bash
git init -b main
git add .
git commit -m "Add Buck-Boost course design, simulations and manufacturing files"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
git push -u origin main
```

仓库以本目录为边界，不要在包含其他个人资料的上层目录执行git add。此前未创建远程仓库、未上传、未设置Git身份。本目录还没有Git历史，便于作者自行决定首次提交内容。
