// Snowball 3.0.1 (libstemmer_c, BSD-3, see COPYING): English and Russian UTF-8 stemmers.
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

/// The result of the last stemming: a pointer to UTF-8 bytes and a length.
const unsigned char * snowball_result(struct SN_env * z, int * length);

#endif
