#include "runtime/api.h"
#include "include/CSnowball.h"

const unsigned char * snowball_result(struct SN_env * z, int * length) {
    *length = z->l;
    return z->p;
}
