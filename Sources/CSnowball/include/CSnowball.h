// Snowball 3.0.1 (libstemmer_c, BSD-3, див. COPYING): англійський і російський стемери UTF-8.
#ifndef CSNOWBALL_H
#define CSNOWBALL_H

struct SN_env;

extern int SN_set_current(struct SN_env * z, int size, const unsigned char * s);

extern struct SN_env * english_UTF_8_create_env(void);
extern void english_UTF_8_close_env(struct SN_env * z);
extern int english_UTF_8_stem(struct SN_env * z);

extern struct SN_env * russian_UTF_8_create_env(void);
extern void russian_UTF_8_close_env(struct SN_env * z);
extern int russian_UTF_8_stem(struct SN_env * z);

/// Результат останнього стемінгу: вказівник на байти UTF-8 і довжина.
const unsigned char * snowball_result(struct SN_env * z, int * length);

#endif
