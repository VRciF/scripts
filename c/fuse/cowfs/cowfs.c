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
#include <stdarg.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <sys/statvfs.h>
#include <stddef.h>
#include <stdlib.h>
#include <linux/limits.h>
#include <time.h>
#include <sys/time.h>

#include "cowfs.h"

#ifndef WITHOUT_XATTR
#include <attr/xattr.h>
#endif


int cow_getattr(const char *path, struct stat *stbuf)
{
    int res;
    LOG("%s",path);
    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }

    res = lstat(fqpath, stbuf);

    free(fqpath);
    if(res == -1)
        return -errno;

    return 0;
}

int cow_readlink(const char *path, char *buf, size_t size)
{
    int res;
    LOG("%s",path);
    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }

    memset(buf, 0, size);
    res = readlink(fqpath, buf, size);

    free(fqpath);

    if(res == -1)
        return -1;

    buf[res] = '\0';
    return 0;
}


int cow_readdir(const char *path, void *buf, fuse_fill_dir_t filler, off_t offset, struct fuse_file_info * fi)
{
    DIR *dp;
    struct dirent *de;
    int res = 0;
    LOG("%s",path);

    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }

    dp = opendir(fqpath);
    free(fqpath);

    if(dp == NULL){
        return -errno;
    }

    while((de = readdir(dp)) != NULL) {
        struct stat st;
        char *object_name = create_path(cow_getConfig()->srcdir, de->d_name);
        if(object_name==NULL) continue;

        lstat(object_name, &st);
        free(object_name);

        filler(buf, de->d_name, &st, 0);
    }

    closedir(dp);
    return res;
}

int cow_utimens(const char *path, const struct timespec ts[2])
{
    int res;
    LOG("%s",path);

    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }
    
    struct timeval tv[2];

    tv[0].tv_sec = ts[0].tv_sec;
    tv[0].tv_usec = ts[0].tv_nsec / 1000;
    tv[1].tv_sec = ts[1].tv_sec;
    tv[1].tv_usec = ts[1].tv_nsec / 1000;

    res = lutimes(fqpath, tv);
    free(fqpath);
    if (res == -1)
        return -errno;

    return 0;
}


int cow_open(const char *path, struct fuse_file_info *finfo)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = open(fqpath, finfo->flags);
        if(res != -1){
            if(i==-1){  /* srcdir path */
                finfo->fh = res;
            }else{  /* dstdirs path */
                close(res);
            }

            struct fuse_context *cntx = fuse_get_context();
            chown(fqpath, cntx->uid,cntx->gid);
        }
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *finfo)
{
    int res;
    LOG("%s",path);

    res = pread(finfo->fh, buf, size, offset);
    if(res == -1)
        res = -errno;
    
    return res;
}

int cow_release(const char *path, struct fuse_file_info *finfo)
{
    /* Just a stub.  This method is optional and can safely be left
       unimplemented */
    LOG("%s",path);

    close(finfo->fh);

    return 0;
}

int cow_fsync(const char *path, int isdatasync, struct fuse_file_info *finfo)
{
    /* Just a stub.  This method is optional and can safely be left
       unimplemented */
    LOG("%s",path);

#ifdef HAVE_FDATASYNC
        if (isdatasync)
                fdatasync(finfo->fh);
        else
#endif
                fsync(finfo->fh);

    return 0;
}
int cow_statfs(const char *path, struct statvfs *buf)
{
    int res = 0;
    LOG("%s",path);

    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }

    res = statvfs(fqpath, buf);
    free(fqpath);
    if(res == -1){ return -errno; }

    return 0;
}
int cow_access(const char *path, int mask)
{
    int res = 0;
    LOG("%s",path);

    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }

    res = access(fqpath, mask);
    free(fqpath);
    if(res == -1){ return -errno; }

    return 0;
}

int cow_create(const char *path, mode_t mode, struct fuse_file_info *finfo)
{
    int i=0;
    int res = 0;
    LOG("%s",path);
    
    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = open(fqpath, finfo->flags, mode);
        if(res != -1){
            if(i==-1){  /* srcdir path */
                finfo->fh = res;
            }else{  /* dstdirs path */
                close(res);
            }   
            
            struct fuse_context *cntx = fuse_get_context();
            chown(fqpath, cntx->uid,cntx->gid);
        }   
    FORDSTDIRS_END(fqpath);
    
    return 0;
}
int cow_mknod(const char *path, mode_t mode, dev_t rdev)
{
    int i=0;
    int res = 0;
    LOG("%s",path);
    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = mknod(fqpath, mode, rdev);
        if( res != -1 ){
            struct fuse_context *cntx = fuse_get_context();
            chown(fqpath, cntx->uid,cntx->gid);
        }
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_mkdir(const char *path, mode_t mode)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = mkdir(fqpath, mode);
        if(res != -1){
            struct fuse_context *cntx = fuse_get_context();
            chown(fqpath, cntx->uid,cntx->gid);
        }
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_unlink(const char *path)
{
    int i=0;
    int res = 0;
    LOG("%s",path);
    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = unlink(fqpath);
        if(res != -1){
            struct fuse_context *cntx = fuse_get_context();
            chown(fqpath, cntx->uid,cntx->gid);
        }
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_rmdir(const char *path)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = rmdir(fqpath);
        if(res != -1){
            struct fuse_context *cntx = fuse_get_context();
            chown(fqpath, cntx->uid,cntx->gid);
        }
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_symlink(const char *from, const char *to)
{
    int i=0;
    int res = 0;
    LOG("%s -> %s",from, to);

    struct cow_config *conf = cow_getConfig();
    char *fqto = NULL;
    FORDSTDIRS_BEGIN(i, res, to, conf, fqto);
        res = symlink(from, fqto);
        if(res != -1){
            struct fuse_context *cntx = fuse_get_context();
            chown(fqto, cntx->uid,cntx->gid);
        }
    FORDSTDIRS_END(fqto);

    return 0;
}

int cow_rename(const char *from, const char *to)
{
    int i=0;
    int res = 0;
    LOG("%s -> %s", from, to);
    struct cow_config *conf = cow_getConfig();
    char *fqfrom = NULL;
    char *fqto = NULL;
    FORDSTDIRS_BEGIN(i, res, to, conf, fqto);
        if(i==-1){
            fqfrom = create_path(cow_getConfig()->srcdir, from);
            if(fqfrom==NULL){ free(fqto); return -errno; }
        }
        else{
            fqfrom = create_path(cow_getConfig()->dstdirs[i], from);
            if(fqfrom==NULL){ free(fqto); continue; }
        }

        res = rename(fqfrom, fqto);
        free(fqfrom);
    FORDSTDIRS_END(fqto);

    return 0;
}

int cow_link(const char *from, const char *to)
{
    int i=0;
    int res = 0;
    LOG("%s -> %s", from, to);
    struct cow_config *conf = cow_getConfig();
    char *fqfrom = NULL;
    char *fqto = NULL;
    FORDSTDIRS_BEGIN(i, res, to, conf, fqto);
        if(i==-1){
            fqfrom = create_path(cow_getConfig()->srcdir, from);
            if(fqfrom==NULL){ free(fqto); return -errno; }
        }
        else{
            fqfrom = create_path(cow_getConfig()->dstdirs[i], from);
            if(fqfrom==NULL){ free(fqto); continue; }
        }
        
        res = link(fqfrom, fqto);
        free(fqfrom);
    FORDSTDIRS_END(fqto);

    return 0;
}

int cow_chmod(const char *path, mode_t mode)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = chmod(fqpath, mode);
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_chown(const char *path, uid_t uid, gid_t gid)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = lchown(fqpath, uid, gid);
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_truncate(const char *path, off_t size)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = truncate(fqpath, size);
    FORDSTDIRS_END(fqpath);

    return 0;
}

int cow_write(const char *path, const char *buf, size_t size,
                     off_t offset, struct fuse_file_info *finfo)
{
    int i=0;
    int res = 0;
    int rval = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        int fd = -1;
        if(i==-1){
            fd = finfo->fh;
        }else{
            fd = open(fqpath, O_WRONLY);
        }

        if(fd != -1){
            res = pwrite(fd, buf, size, offset);
            if(i != -1){
                close(fd);
            }
            else{
                rval = res;
            }
        }
    FORDSTDIRS_END(fqpath);

    return rval;
}


int cow_ftruncate(const char *path, off_t size,
                struct fuse_file_info *finfo)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;

    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        int fd = -1;
        if(i==-1){
            fd = finfo->fh;
        }else{
            fd = open(fqpath, O_WRONLY);
        }

        if(fd != -1){
            res = ftruncate(fd, size);
            if(i != -1){
                close(fd);
            }
        }
    FORDSTDIRS_END(fqpath);

    return 0;
}

#ifndef WITHOUT_XATTR
int cow_removexattr(const char *path, const char *attrname)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = removexattr(fqpath, attrname);
    FORDSTDIRS_END(fqpath);

    return 0;
}
#endif

#ifndef WITHOUT_XATTR
int cow_setxattr(const char *path, const char *attrname,
                 const char *attrval, size_t attrvalsize, int flags)
{
    int i=0;
    int res = 0;
    LOG("%s",path);

    struct cow_config *conf = cow_getConfig();
    char *fqpath = NULL;
    FORDSTDIRS_BEGIN(i, res, path, conf, fqpath);
        res = setxattr(fqpath, attrname, attrval, attrvalsize, flags);
    FORDSTDIRS_END(fqpath);

    return 0;
}
#endif

#ifndef WITHOUT_XATTR
int cow_getxattr(const char *path, const char *attrname, char *buf, size_t count)
{
    int size = 0;
    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }

    size = getxattr(fqpath, attrname, buf, count);
    free(fqpath);
    if (size == -1) return -errno;
    return size;
}
#endif

#ifndef WITHOUT_XATTR
int cow_listxattr(const char *path, char *buf, size_t count)
{
    int res = 0;
    char *fqpath = create_path(cow_getConfig()->srcdir, path);
    if(fqpath==NULL){ return -errno; }

    res=listxattr(fqpath, buf, count);
    free(fqpath);
    if (res == -1) return -errno;
    return res;
}
#endif

inline struct cow_config* cow_getConfig(){
    static struct cow_config conf = {0};
    return &conf;
}
inline void cow_log(const char *file, int line, const char *function, const char *format, ...){
    va_list ap;
    time_t now;
    char stime[28] = {'\0'};
    char errstr[128] = {'\0'};

    static FILE *lfile = NULL;
    strerror_r(errno, errstr, sizeof(errstr)-1);

    if(lfile==NULL){
        lfile = fopen("/tmp/cowfs.log","a+");
        if(lfile==NULL){ return; }
    }

    now = time(NULL);
    ctime_r(&now, stime);
    if(strlen(stime)>0)
        stime[strlen(stime)-1] = '\0';

    va_start (ap, format);         /* Initialize the argument list. */
    fprintf(lfile, "%s - %s:%d:%s[%d:%s] - ", stime, file, line, function, errno, errstr);
    vfprintf(lfile,format, ap);
    fprintf(lfile, "\n");
    fflush(lfile);
    va_end (ap);                  /* Clean up. */
}
char * create_path(const char *dir, const char * file)
{
    if (file[0]=='/') file++;
    int plen=strlen(dir);
    int flen=strlen(file);

    char *path=(char *)calloc(plen+flen+2, sizeof(char));
    if(path==NULL){
        LOG("allocation of '%d' bytes failed", plen+flen+2);
        return NULL;
    }

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
int add_dir(const char * dir)
{
    char **newdirs;
    char *add_dir;
    struct cow_config *conf = cow_getConfig();

    if (*dir=='/')
    {
        add_dir=strdup(dir);
    }
    else
    {
        add_dir = create_path(conf->cwd, dir);
    }

    if (!conf->dstdirs)
    {
        conf->dstdirs = calloc(1, sizeof(char *));
        conf->dstdircnt = 1;
    }
    else{
        newdirs = realloc(conf->dstdirs, (conf->dstdircnt+1)*sizeof(char*));
        if(newdirs==NULL){
            return 0;
        }
        conf->dstdircnt++;
    }
    conf->dstdirs[conf->dstdircnt-1] = add_dir;

    return 1;
}

int cow_opt_proc(void *data, const char *arg, int key, struct fuse_args *outargs)
{
    struct cow_config *conf = cow_getConfig();
    switch(key)
    {
        case FUSE_OPT_KEY_NONOPT:
        {
            if(conf->srcdir == NULL){
                /* parse src=dst1,dst2,....,dstn */
                char *eq = strstr(arg, "=");
                if(eq==NULL){
                    fprintf(stderr, "ERROR: invalid source specifier given, '%s' (missing a '=' character)", arg);
                    exit(-1);
                }
                if(arg[0]=='/'){
                    conf->srcdir = calloc((eq-arg)+1, sizeof(char));
                    if(conf->srcdir==NULL){
                        fprintf(stderr, "ERROR: Couldn't allocate memory for source specifier");
                        exit(-1);
                    }
                    strncpy(conf->srcdir, arg, eq-arg);
                }
                else{
                    conf->srcdir = calloc(strlen(conf->cwd)+1+(eq-arg)+1, sizeof(char));
                    if(conf->srcdir==NULL){
                        fprintf(stderr, "ERROR: Couldn't allocate memory for source specifier");
                        exit(-1);
                    }
                    strcpy(conf->srcdir, conf->cwd);
                    conf->srcdir[strlen(conf->cwd)]='/';
                    strncpy(conf->srcdir+strlen(conf->cwd)+1, arg, eq-arg);
                }

                arg = eq+1;
                const char *eod = NULL; /* end of destination */
                do{
                    eod = strstr(arg, ",");
                    if(eod==NULL){
                        eod = arg+strlen(arg);
                    }
                    if(eod==arg){ break; }

                    char *adir = calloc(eod-arg+1, sizeof(char));
                    if(adir==NULL){
                        fprintf(stderr, "ERROR: directory buffer allocation failed (%d)", errno);
                        exit(0);
                    }
                    strncpy(adir, arg, eod-arg);
                    add_dir(adir);
                    free(adir);

                    arg = eod;
                    if(eod[0]==','){ arg++; }

                    eod = NULL;
                }while(eod != arg);
            }
            else{
                if(arg[0]=='/'){
                    conf->mountpt = strdup(arg);
                }
                else{
                    conf->mountpt = create_path(conf->cwd, arg);
                }
            }

            return 0;
        }
    }
    return 1;
}
struct fuse_args * parse_options(int argc, char *argv[])
{
     struct fuse_args * args=calloc(1, sizeof(struct fuse_args));
     struct cow_config *conf = cow_getConfig();
     int pathmaxcnt = 0;

     do{
         pathmaxcnt++;
         conf->cwd = calloc(PATH_MAX*pathmaxcnt, sizeof(char));
         if(getcwd(conf->cwd, PATH_MAX*pathmaxcnt)==NULL){
             free(conf->cwd);
             conf->cwd = NULL;
         }
     }while(conf->cwd==NULL && errno == ERANGE);
     if(conf->cwd==NULL){
         fprintf(stderr, "ERROR: couldnt allocate current working directory buffer (%d)\n", errno);
         exit(-1);
     }

     {
         struct fuse_args tmp=FUSE_ARGS_INIT(argc, argv);
         memcpy(args, &tmp, sizeof(struct fuse_args));
     }

     if (fuse_opt_parse(args, cow_getConfig(), cow_opts, cow_opt_proc)==-1)
         exit(-1);

     char *cliopt = NULL;
     int clilen = strlen(FUSE_MP_OPT_STR)+strlen(conf->srcdir)+1;
     int i = 0;
     for(i=0;i<conf->dstdircnt;i++){
         if(i) clilen++; /* separator character */

         clilen += strlen(conf->dstdirs[i]);
     }
     clilen++; /* null byte */
     cliopt = calloc(clilen, sizeof(char));
     sprintf(cliopt, "%s%s=", FUSE_MP_OPT_STR, conf->srcdir);
     for(i=0;i<conf->dstdircnt;i++){
         if(i) strcat(cliopt, ";");
         strcat(cliopt, conf->dstdirs[i]);
     }

     fuse_opt_insert_arg(args, 1, cliopt);
     fuse_opt_insert_arg(args, 1, conf->mountpt);

     return args;
}


int main(int argc, char *argv[])
{
     struct fuse_args *args = NULL;

     args = parse_options(argc, argv);
     return fuse_main(args->argc, args->argv, &cow_oper, 0);
}

