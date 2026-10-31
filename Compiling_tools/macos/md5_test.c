/* RFC 1321 appendix A.5 test suite for md5.c; exits non-zero on a mismatch. */
#include <stdio.h>
#include <string.h>
#include "md5.h"

int main(void)
{
    static const char *const tests[][2] = {
        {"", "d41d8cd98f00b204e9800998ecf8427e"},
        {"a", "0cc175b9c0f1b6a831c399e269772661"},
        {"abc", "900150983cd24fb0d6963f7d28e17f72"},
        {"message digest", "f96b697d7cb7938d525a2f31aaf161d0"},
        {"abcdefghijklmnopqrstuvwxyz", "c3fcd3d76192e4007dfb496cca67e13b"},
        {"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", "d174ab98d277d9f5a5611c2c9f419d9f"},
        {"12345678901234567890123456789012345678901234567890123456789012345678901234567890", "57edf4a22be3c955ac49da2e2107b67a"},
    };
    int failed = 0;
    for (size_t t = 0; t < sizeof tests / sizeof tests[0]; t++) {
        md5_state_t st;
        md5_byte_t d[16];
        char hex[33];
        const char *s = tests[t][0];
        /* Fed in two pieces, to exercise the partial-block path too. */
        size_t half = strlen(s) / 2;
        md5_init(&st);
        md5_append(&st, (const md5_byte_t *)s, (int)half);
        md5_append(&st, (const md5_byte_t *)s + half, (int)(strlen(s) - half));
        md5_finish(&st, d);
        for (int i = 0; i < 16; i++)
            sprintf(hex + i * 2, "%02x", d[i]);
        if (strcmp(hex, tests[t][1]) != 0) {
            printf("FAIL MD5(\"%s\") = %s, expected %s\n", s, hex, tests[t][1]);
            failed = 1;
        }
    }
    puts(failed ? "md5: FAILED" : "md5: all RFC 1321 tests pass");
    return failed;
}
