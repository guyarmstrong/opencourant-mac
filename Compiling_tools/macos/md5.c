/*
 * MD5 (RFC 1321) for the md5.h interface in OpenCourant's extlib
 * (md5_init / md5_append / md5_finish on md5_state_t). extlib ships this
 * library prebuilt for Linux and Windows only; the macOS build compiles it
 * from this file (Compiling_tools/macos/build_deps.sh).
 *
 * Written from RFC 1321 for the OpenCourant macOS port; checked against the
 * RFC's test suite (Compiling_tools/macos/md5_test.c).
 * Same licence as OpenCourant (AGPL-3.0-or-later).
 */
#include <string.h>
#include "md5.h"

#define F(x, y, z) (((x) & (y)) | (~(x) & (z)))
#define G(x, y, z) (((x) & (z)) | ((y) & ~(z)))
#define H(x, y, z) ((x) ^ (y) ^ (z))
#define I(x, y, z) ((y) ^ ((x) | ~(z)))
#define ROTL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))
#define STEP(f, a, b, c, d, x, t, s) \
    (a) += f((b), (c), (d)) + (x) + (t); \
    (a) = ROTL((a), (s)) + (b)

static void md5_process(md5_state_t *pms, const md5_byte_t *data)
{
    md5_word_t a = pms->abcd[0], b = pms->abcd[1], c = pms->abcd[2], d = pms->abcd[3];
    md5_word_t X[16];
    int i;

    /* Little-endian words, whatever the CPU. */
    for (i = 0; i < 16; i++)
        X[i] = (md5_word_t)data[i * 4] | ((md5_word_t)data[i * 4 + 1] << 8) |
               ((md5_word_t)data[i * 4 + 2] << 16) | ((md5_word_t)data[i * 4 + 3] << 24);

    STEP(F, a, b, c, d, X[0], 0xd76aa478, 7);
    STEP(F, d, a, b, c, X[1], 0xe8c7b756, 12);
    STEP(F, c, d, a, b, X[2], 0x242070db, 17);
    STEP(F, b, c, d, a, X[3], 0xc1bdceee, 22);
    STEP(F, a, b, c, d, X[4], 0xf57c0faf, 7);
    STEP(F, d, a, b, c, X[5], 0x4787c62a, 12);
    STEP(F, c, d, a, b, X[6], 0xa8304613, 17);
    STEP(F, b, c, d, a, X[7], 0xfd469501, 22);
    STEP(F, a, b, c, d, X[8], 0x698098d8, 7);
    STEP(F, d, a, b, c, X[9], 0x8b44f7af, 12);
    STEP(F, c, d, a, b, X[10], 0xffff5bb1, 17);
    STEP(F, b, c, d, a, X[11], 0x895cd7be, 22);
    STEP(F, a, b, c, d, X[12], 0x6b901122, 7);
    STEP(F, d, a, b, c, X[13], 0xfd987193, 12);
    STEP(F, c, d, a, b, X[14], 0xa679438e, 17);
    STEP(F, b, c, d, a, X[15], 0x49b40821, 22);

    STEP(G, a, b, c, d, X[1], 0xf61e2562, 5);
    STEP(G, d, a, b, c, X[6], 0xc040b340, 9);
    STEP(G, c, d, a, b, X[11], 0x265e5a51, 14);
    STEP(G, b, c, d, a, X[0], 0xe9b6c7aa, 20);
    STEP(G, a, b, c, d, X[5], 0xd62f105d, 5);
    STEP(G, d, a, b, c, X[10], 0x02441453, 9);
    STEP(G, c, d, a, b, X[15], 0xd8a1e681, 14);
    STEP(G, b, c, d, a, X[4], 0xe7d3fbc8, 20);
    STEP(G, a, b, c, d, X[9], 0x21e1cde6, 5);
    STEP(G, d, a, b, c, X[14], 0xc33707d6, 9);
    STEP(G, c, d, a, b, X[3], 0xf4d50d87, 14);
    STEP(G, b, c, d, a, X[8], 0x455a14ed, 20);
    STEP(G, a, b, c, d, X[13], 0xa9e3e905, 5);
    STEP(G, d, a, b, c, X[2], 0xfcefa3f8, 9);
    STEP(G, c, d, a, b, X[7], 0x676f02d9, 14);
    STEP(G, b, c, d, a, X[12], 0x8d2a4c8a, 20);

    STEP(H, a, b, c, d, X[5], 0xfffa3942, 4);
    STEP(H, d, a, b, c, X[8], 0x8771f681, 11);
    STEP(H, c, d, a, b, X[11], 0x6d9d6122, 16);
    STEP(H, b, c, d, a, X[14], 0xfde5380c, 23);
    STEP(H, a, b, c, d, X[1], 0xa4beea44, 4);
    STEP(H, d, a, b, c, X[4], 0x4bdecfa9, 11);
    STEP(H, c, d, a, b, X[7], 0xf6bb4b60, 16);
    STEP(H, b, c, d, a, X[10], 0xbebfbc70, 23);
    STEP(H, a, b, c, d, X[13], 0x289b7ec6, 4);
    STEP(H, d, a, b, c, X[0], 0xeaa127fa, 11);
    STEP(H, c, d, a, b, X[3], 0xd4ef3085, 16);
    STEP(H, b, c, d, a, X[6], 0x04881d05, 23);
    STEP(H, a, b, c, d, X[9], 0xd9d4d039, 4);
    STEP(H, d, a, b, c, X[12], 0xe6db99e5, 11);
    STEP(H, c, d, a, b, X[15], 0x1fa27cf8, 16);
    STEP(H, b, c, d, a, X[2], 0xc4ac5665, 23);

    STEP(I, a, b, c, d, X[0], 0xf4292244, 6);
    STEP(I, d, a, b, c, X[7], 0x432aff97, 10);
    STEP(I, c, d, a, b, X[14], 0xab9423a7, 15);
    STEP(I, b, c, d, a, X[5], 0xfc93a039, 21);
    STEP(I, a, b, c, d, X[12], 0x655b59c3, 6);
    STEP(I, d, a, b, c, X[3], 0x8f0ccc92, 10);
    STEP(I, c, d, a, b, X[10], 0xffeff47d, 15);
    STEP(I, b, c, d, a, X[1], 0x85845dd1, 21);
    STEP(I, a, b, c, d, X[8], 0x6fa87e4f, 6);
    STEP(I, d, a, b, c, X[15], 0xfe2ce6e0, 10);
    STEP(I, c, d, a, b, X[6], 0xa3014314, 15);
    STEP(I, b, c, d, a, X[13], 0x4e0811a1, 21);
    STEP(I, a, b, c, d, X[4], 0xf7537e82, 6);
    STEP(I, d, a, b, c, X[11], 0xbd3af235, 10);
    STEP(I, c, d, a, b, X[2], 0x2ad7d2bb, 15);
    STEP(I, b, c, d, a, X[9], 0xeb86d391, 21);

    pms->abcd[0] += a;
    pms->abcd[1] += b;
    pms->abcd[2] += c;
    pms->abcd[3] += d;
}

void md5_init(md5_state_t *pms)
{
    pms->count[0] = pms->count[1] = 0;
    pms->abcd[0] = 0x67452301;
    pms->abcd[1] = 0xefcdab89;
    pms->abcd[2] = 0x98badcfe;
    pms->abcd[3] = 0x10325476;
}

void md5_append(md5_state_t *pms, const md5_byte_t *data, int nbytes)
{
    const md5_byte_t *p = data;
    int left = nbytes;
    int offset = (pms->count[0] >> 3) & 63;
    md5_word_t nbits = (md5_word_t)(nbytes << 3);

    if (nbytes <= 0)
        return;

    /* Message length in bits. */
    pms->count[1] += nbytes >> 29;
    pms->count[0] += nbits;
    if (pms->count[0] < nbits)
        pms->count[1]++;

    /* Fill a partial block first. */
    if (offset) {
        int copy = (offset + nbytes > 64 ? 64 - offset : nbytes);
        memcpy(pms->buf + offset, p, copy);
        if (offset + copy < 64)
            return;
        p += copy;
        left -= copy;
        md5_process(pms, pms->buf);
    }

    for (; left >= 64; p += 64, left -= 64)
        md5_process(pms, p);

    if (left)
        memcpy(pms->buf, p, left);
}

void md5_finish(md5_state_t *pms, md5_byte_t digest[16])
{
    static const md5_byte_t pad[64] = {0x80};
    md5_byte_t data[8];
    int i;

    /* Length before padding, little-endian. */
    for (i = 0; i < 8; ++i)
        data[i] = (md5_byte_t)(pms->count[i >> 2] >> ((i & 3) << 3));
    /* Pad to 56 bytes mod 64, then the length. */
    md5_append(pms, pad, ((55 - (pms->count[0] >> 3)) & 63) + 1);
    md5_append(pms, data, 8);
    for (i = 0; i < 16; ++i)
        digest[i] = (md5_byte_t)(pms->abcd[i >> 2] >> ((i & 3) << 3));
}
