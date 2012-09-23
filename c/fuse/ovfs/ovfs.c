/*
    FUSE: Filesystem in Userspace
    Copyright (C) 2001  Miklos Szeredi (mszeredi@inf.bme.hu)

    This program can be distributed under the terms of the GNU GPL.
    See the file COPYING.
*/

#define _XOPEN_SOURCE 600
#define _BSD_SOURCE 1

#include <fuse.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <sys/statvfs.h>
#include <stddef.h>
#include <stdlib.h>
#include <linux/limits.h>
#include "ovfs.h"

#ifndef WITHOUT_XATTR
#include <attr/xattr.h>
#endif


int ov_getattr(const char *path, struct stat *stbuf)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = lstat(fqpath, stbuf);

    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_readlink(const char *path, char *buf, size_t size)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = readlink(fqpath, buf, size - 1);

    free(fqpath);

    if(res == -1)
        return -errno;

    buf[res] = '\0';
    return 0;
}


int ov_getdir(const char *path, fuse_dirh_t h, fuse_dirfil_t filler)
{
    DIR *dp;
    struct dirent *de;
    int res = 0;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    dp = opendir(fqpath);
    free(fqpath);

    if(dp == NULL){
        return -errno;
    }

    while((de = readdir(dp)) != NULL) {
        res = filler(h, de->d_name, de->d_type, de->d_ino);
        if(res != 0)
            break;
    }

    closedir(dp);
    return res;
}

int ov_utime(const char *path, struct utimbuf *buf)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }
    
    res = utime(fqpath, buf);
    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}


int ov_open(const char *path, struct fuse_file_info *finfo)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = open(fqpath, finfo->flags);
    if(res == -1){ 
        free(fqpath);
        return -errno;
    }

    struct fuse_context *cntx = fuse_get_context();
    chown(fqpath, cntx->uid,cntx->gid);
    free(fqpath);

    close(res);
    return 0;
}

int ov_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *finfo)
{
    int fd;
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    fd = open(fqpath, O_RDONLY);
    free(fqpath);

    if(fd == -1)
        return -errno;

    res = pread(fd, buf, size, offset);
    if(res == -1)
        res = -errno;
    
    close(fd);
    return res;
}

int ov_release(const char *path, struct fuse_file_info *finfo)
{
    /* Just a stub.  This method is optional and can safely be left
       unimplemented */

    (void) path;
    (void) finfo->flags;
    return 0;
}

int ov_fsync(const char *path, int isdatasync, struct fuse_file_info *finfo)
{
    /* Just a stub.  This method is optional and can safely be left
       unimplemented */

    (void) path;
    (void) isdatasync;
    return 0;
}
int ov_statfs(const char *path, struct statvfs *buf)
{
    int res = 0;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = statvfs(fqpath, buf);
    free(fqpath);
    if(res == -1){ return -errno; }

    return 0;
}

int ov_mknod(const char *path, mode_t mode, dev_t rdev)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = mknod(fqpath, mode, rdev);
    if(res == -1){
        free(fqpath);
        return -errno;
    }

    struct fuse_context *cntx = fuse_get_context();
    chown(fqpath, cntx->uid,cntx->gid);
    free(fqpath);

    return 0;
}

int ov_mkdir(const char *path, mode_t mode)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = mkdir(fqpath, mode);
    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_unlink(const char *path)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = unlink(fqpath);
    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_rmdir(const char *path)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = rmdir(fqpath);
    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_symlink(const char *from, const char *to)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, to);
    if(fqpath==NULL){ return -errno; }

    res = symlink(from, fqpath);
    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_rename(const char *from, const char *to)
{
    int res;
    char *fqfrom = create_path(ov_getConfig()->ovdir, from);
    if(fqfrom==NULL){ return -errno; }
    char *fqto = create_path(ov_getConfig()->ovdir, to);
    if(fqto==NULL){ free(fqfrom); return -errno; }

    res = rename(fqfrom, fqto);
    free(fqto);
    free(fqfrom);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_link(const char *from, const char *to)
{
    int res;
    char *fqfrom = create_path(ov_getConfig()->ovdir, from);
    if(fqfrom==NULL){ return -errno; }
    char *fqto = create_path(ov_getConfig()->ovdir, to);
    if(fqto==NULL){ free(fqfrom); return -errno; }

    res = link(fqfrom, fqto);
    free(fqto);
    free(fqfrom);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_chmod(const char *path, mode_t mode)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = chmod(fqpath, mode);
    free(fqpath);
    if(res == -1)
        return -errno;
    
    return 0;
}

int ov_chown(const char *path, uid_t uid, gid_t gid)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = lchown(fqpath, uid, gid);
    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_truncate(const char *path, off_t size)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = truncate(fqpath, size);
    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int ov_write(const char *path, const char *buf, size_t size,
                     off_t offset, struct fuse_file_info *finfo)
{
    int fd;
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    fd = open(fqpath, O_WRONLY);
    free(fqpath);
    if(fd == -1)
        return -errno;

    res = pwrite(fd, buf, size, offset);
    if(res == -1)
        res = -errno;
    
    close(fd);
    return res;
}


int ov_ftruncate(const char *path, off_t size,
                struct fuse_file_info *fi)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    int fd = open(fqpath, O_RDWR);
    free(fqpath);
    if (fd == -1)
        return -errno;
    res = ftruncate(fd, size);
    if (res == -1)
        return -errno;
   return res;
}

#ifndef WITHOUT_XATTR
int ov_removexattr(const char *path, const char *attrname)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = removexattr(fqpath, attrname);
    free(fqpath);
    if (res == -1) return -errno;
    return 0;
}
#endif

#ifndef WITHOUT_XATTR
int ov_setxattr(const char *path, const char *attrname,
                const char *attrval, size_t attrvalsize, int flags)
{
    int res;
    char *fqpath = create_path(ov_getConfig()->ovdir, path);
    if(fqpath==NULL){ return -errno; }

    res = setxattr(fqpath, attrname, attrval, attrvalsize, flags);
    free(fqpath);
    if (res == -1) return -errno;
    return 0;
}
#endif


struct ov_config* ov_getConfig(){
    static struct ov_config conf = {0};
    return &conf;
}
char * create_path(const char *dir, const char * file)
{
    if (file[0]=='/') file++;
    int plen=strlen(dir);
    int flen=strlen(file);

    char *path=(char *)calloc(plen+flen+2, sizeof(char));
    if(path==NULL){ return NULL; }

    if (dir[plen-1]=='/')
    {
        sprintf(path, "%s%s", dir, file);
    }
    else
    {
        sprintf(path, "%s/%s", dir, file);
    }

    plen=strlen(path);
    if (plen>1 && path[plen-1]=='/') path[plen-1]=0;

    return path;
}

int ov_opt_proc(void *data, const char *arg, int key, struct fuse_args *outargs)
{
        struct ov_config *conf = ov_getConfig();
        switch(key)
        {
                case FUSE_OPT_KEY_NONOPT:
                        {
                            char *tmp = NULL;

                            if(arg[0]!='/'){
                                char cpwd[PATH_MAX];
                                getcwd(cpwd, PATH_MAX);
                                tmp = calloc(1, strlen(cpwd)+1+strlen(arg)+1);
                                memcpy(tmp, cpwd, strlen(cpwd));
                                tmp[strlen(cpwd)] = '/';
                                memcpy(tmp+strlen(cpwd)+1, arg, strlen(arg));
                            }
                            else{
                                tmp = calloc(1, strlen(arg)+1);
                                memcpy(tmp, arg, strlen(arg));
                            }

                            if(conf->ovdir == NULL){
                                conf->ovdir = tmp;
                            }
                            else if(conf->mountpt == NULL){
                                conf->mountpt = tmp;
                            }
                            else{
                                free(conf->ovdir);
                                conf->ovdir = conf->mountpt;
                                conf->mountpt = tmp;
                            }

                            return 0;
                        }
        }
        return 1;
}
struct fuse_args * parse_options(int argc, char *argv[])
{
     struct fuse_args * args=calloc(1, sizeof(struct fuse_args));
     struct ov_config *conf = ov_getConfig();

     {
         struct fuse_args tmp=FUSE_ARGS_INIT(argc, argv);
         memcpy(args, &tmp, sizeof(struct fuse_args));
     }

     if (fuse_opt_parse(args, ov_getConfig(), ov_opts, ov_opt_proc)==-1)
         exit(-1);

     printf("mountpt: %s\n", conf->mountpt);

     char *cliopt = NULL;
     cliopt = calloc(1,strlen(FUSE_MP_OPT_STR)+strlen(conf->ovdir)+1);
     sprintf(cliopt, "%s%s", FUSE_MP_OPT_STR, conf->ovdir);
     printf("cliopt: %s\n",cliopt);
     fuse_opt_insert_arg(args, 1, cliopt);

     fuse_opt_insert_arg(args, 1, conf->mountpt);

     return args;
}


int main(int argc, char *argv[])
{
     struct fuse_args *args = parse_options(argc, argv);
     return fuse_main(args->argc, args->argv, &ov_oper, 0);
}

