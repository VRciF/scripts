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
struct ov_config {
     char *ovdir;
     char *mountpt;
};

enum {
     KEY_HELP,
     KEY_VERSION,
};

#define OV_OPT(t, p, v) { t, offsetof(struct ov_config, p), v }

struct fuse_opt ov_opts[] = {
/*
     XMP_OPT("mynum=%i",          mynum, 0),
     XMP_OPT("-n %i",             mynum, 0),
     XMP_OPT("mystring=%s",       mystring, 0),
     XMP_OPT("mybool",            mybool, 1),
     XMP_OPT("nomybool",          mybool, 0),
     XMP_OPT("--mybool=true",     mybool, 1),
     XMP_OPT("--mybool=false",    mybool, 0),
*/
     FUSE_OPT_KEY("-V",             KEY_VERSION),
     FUSE_OPT_KEY("--version",      KEY_VERSION),
     FUSE_OPT_KEY("-h",             KEY_HELP),
     FUSE_OPT_KEY("--help",         KEY_HELP),
     FUSE_OPT_END
};

int ov_getattr(const char *path, struct stat *stbuf);
int ov_readlink(const char *path, char *buf, size_t size);
int ov_getdir(const char *path, fuse_dirh_t h, fuse_dirfil_t filler);
int ov_utime(const char *path, struct utimbuf *buf);
int ov_open(const char *path, struct fuse_file_info *finfo);
int ov_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *finfo);
int ov_release(const char *path, struct fuse_file_info *finfo);
int ov_fsync(const char *path, int isdatasync, struct fuse_file_info *finfo);
int ov_statfs(const char *path, struct statvfs *buf);
int ov_mknod(const char *path, mode_t mode, dev_t rdev);
int ov_mkdir(const char *path, mode_t mode);
int ov_unlink(const char *path);
int ov_rmdir(const char *path);
int ov_symlink(const char *from, const char *to);
int ov_rename(const char *from, const char *to);
int ov_link(const char *from, const char *to);
int ov_chmod(const char *path, mode_t mode);
int ov_chown(const char *path, uid_t uid, gid_t gid);
int ov_truncate(const char *path, off_t size);
int ov_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *finfo);
/*int ov_ftruncate(const char *path, off_t size, struct fuse_file_info *fi);*/
int ov_removexattr(const char *path, const char *attrname);
int ov_setxattr(const char *path, const char *attrname,
                       const char *attrval, size_t attrvalsize, int flags);

struct ov_config* ov_getConfig();
char * create_path(const char *dir, const char * file);
int ov_opt_proc(void *data, const char *arg, int key, struct fuse_args *outargs);

struct fuse_operations ov_oper = {
    .getattr    = ov_getattr,
    .readlink   = ov_readlink,
    .getdir     = ov_getdir,
    .utime      = ov_utime,
    .open       = ov_open,
    .read       = ov_read,
    .statfs     = ov_statfs,
    .release    = ov_release,
    .fsync      = ov_fsync,

#ifndef WITHOUT_XATTR
        .setxattr       = ov_setxattr,
        .removexattr    = ov_removexattr,
#endif

    .mknod      = ov_mknod,
    .mkdir      = ov_mkdir,
    .symlink    = ov_symlink,
    .unlink     = ov_unlink,
    .rmdir      = ov_rmdir,
    .rename     = ov_rename,
    .link       = ov_link,
    .chmod      = ov_chmod,
    .chown      = ov_chown,
    .truncate   = ov_truncate,
/*    .ftruncate  = ov_ftruncate,*/
    .write      = ov_write
};


