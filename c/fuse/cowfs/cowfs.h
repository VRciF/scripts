/*
    FUSE: Filesystem in Userspace
    Copyright (C) 2001  Miklos Szeredi (mszeredi@inf.bme.hu)

    This program can be distributed under the terms of the GNU GPL.
    See the file COPYING.
*/

#define PACKAGE_VERSION "0.0.1"

#if FUSE_VERSION >= 27
#define FUSE_MP_OPT_STR "-osubtype=ovfs,fsname="
#else
#define FUSE_MP_OPT_STR "-ofsname=ovfs#"
#endif

#include <fuse.h>

//And a more complex example:
struct cow_config {
     char *cwd;

     char *srcdir;
     char **dstdirs;
     int dstdircnt;

     char *mountpt;
};
#define FORDSTDIRS_BEGIN(i, res, path, conf, fqpath) for(i=-1,res=-1;i<conf->dstdircnt;i++){ \
                                              if(i==-1){ \
                                                  fqpath = create_path(conf->srcdir, path); \
                                                  if(fqpath==NULL){ return -errno; } \
                                              }else{ \
                                                  fqpath = create_path(cow_getConfig()->dstdirs[i], path); \
                                                  if(fqpath==NULL){ continue; } \
                                              }
#define FORDSTDIRS_END(fqpath) if(res == -1){ \
                             free(fqpath); \
                             if(i==-1){ LOG("operation failed"); return -errno; } \
                             continue; \
                         } \
                     }

enum {
     KEY_HELP,
     KEY_VERSION,
};

#define COW_OPT(t, p, v) { t, offsetof(struct cow_config, p), v }

struct fuse_opt cow_opts[] = {
     FUSE_OPT_KEY("-V",             KEY_VERSION),
     FUSE_OPT_KEY("--version",      KEY_VERSION),
     FUSE_OPT_KEY("-h",             KEY_HELP),
     FUSE_OPT_KEY("--help",         KEY_HELP),
     FUSE_OPT_END
};

int cow_getattr(const char *path, struct stat *stbuf);
int cow_readlink(const char *path, char *buf, size_t size);
int cow_readdir(const char *dirname, void *buf, fuse_fill_dir_t filler, off_t offset, struct fuse_file_info * fi);
int cow_utimens(const char *path, const struct timespec ts[2]);
int cow_open(const char *path, struct fuse_file_info *finfo);
int cow_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *finfo);
int cow_release(const char *path, struct fuse_file_info *finfo);
int cow_fsync(const char *path, int isdatasync, struct fuse_file_info *finfo);
int cow_statfs(const char *path, struct statvfs *buf);
int cow_access(const char *path, int mask);
int cow_create(const char *path, mode_t mode, struct fuse_file_info *finfo);
int cow_mknod(const char *path, mode_t mode, dev_t rdev);
int cow_mkdir(const char *path, mode_t mode);
int cow_unlink(const char *path);
int cow_rmdir(const char *path);
int cow_symlink(const char *from, const char *to);
int cow_rename(const char *from, const char *to);
int cow_link(const char *from, const char *to);
int cow_chmod(const char *path, mode_t mode);
int cow_chown(const char *path, uid_t uid, gid_t gid);
int cow_truncate(const char *path, off_t size);
int cow_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *finfo);
int cow_ftruncate(const char *path, off_t size, struct fuse_file_info *finfo);
int cow_removexattr(const char *path, const char *attrname);
int cow_setxattr(const char *path, const char *attrname,
                 const char *attrval, size_t attrvalsize, int flags);
int cow_getxattr(const char *path, const char *attrname, char *buf, size_t count);
int cow_listxattr(const char *path, char *buf, size_t count);

inline struct cow_config* cow_getConfig();

inline void cow_log(const char *file, int line, const char *function, const char *format, ...);
#define LOG(...) cow_log(__FILE__,__LINE__,__FUNCTION__, __VA_ARGS__)

char * create_path(const char *dir, const char * file);
int add_dir(const char * dir);
int cow_opt_proc(void *data, const char *arg, int key, struct fuse_args *outargs);

struct fuse_operations cow_oper = {
    .getattr    = cow_getattr,
    .readlink   = cow_readlink,
    .readdir    = cow_readdir,
    .open       = cow_open,
    .read       = cow_read,
    .statfs     = cow_statfs,
    .release    = cow_release,
    .fsync      = cow_fsync,
    .access     = cow_access,
    .utimens    = cow_utimens,

#ifndef WITHOUT_XATTR
    .setxattr       = cow_setxattr,
    .removexattr    = cow_removexattr,
    .getxattr       = cow_getxattr,
    .listxattr      = cow_listxattr,
#endif

    .create     = cow_create,
    .mknod      = cow_mknod,
    .mkdir      = cow_mkdir,
    .symlink    = cow_symlink,
    .unlink     = cow_unlink,
    .rmdir      = cow_rmdir,
    .rename     = cow_rename,
    .link       = cow_link,
    .chmod      = cow_chmod,
    .chown      = cow_chown,
    .truncate   = cow_truncate,
    .ftruncate  = cow_ftruncate,
    .write      = cow_write

};

