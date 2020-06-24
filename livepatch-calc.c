#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

#include <linux/kernel.h>
#include <linux/livepatch.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/version.h>

#include "expression.h"

MODULE_LICENSE("Dual MIT/GPL");
MODULE_AUTHOR("National Cheng Kung University, Taiwan");
MODULE_DESCRIPTION("Patch calc kernel module");
MODULE_VERSION("0.1");

void livepatch_nop_cleanup(struct expr_func *f, void *c)
{
    /* suppress compilation warnings */
    (void) f;
    (void) c;
}

int livepatch_nop(struct expr_func *f, vec_expr_t args, void *c)
{
    (void) args;
    (void) c;
    pr_err("function nop is now patched\n");
    return 0;
}

noinline int livepatch_kfib(int n)
{
    /* The position of the highest bit of n. */
    /* So we need to loop `rounds` times to get the answer. */
    int rounds = 0;
    int a = 0, b = 1; /* F(0), F(1) */
    for (int i = n; i; ++rounds, i >>= 1)
        ;

    for (int i = rounds; i > 0; i--) {
        int t1, t2;
        /* F(2n) = F(n)[2F(n+1) − F(n)] */
        t1 = a * (2 * b - a);

        /* F(2n+1) = F(n+1)^2 + F(n)^2 */
        t2 = b * b + a * a;

        if ((n >> (i - 1)) & 1) {
            a = t2;      /* Threat F(2n+1) as F(n) next round. */
            b = t1 + t2; /* Threat F(2n) + F(2n+1) as F(n+1) next round. */
        } else {
            a = t1; /* Threat F(2n) as F(n) next round. */
            b = t2; /* Threat F(2n+1) as F(n+1) next round. */
        }
    }

    return a;
}

/* clang-format off */
static struct klp_func funcs[] = {
    {
        .old_name = "user_func_nop",
        .new_func = livepatch_nop,
    },
    {
        .old_name = "user_func_nop_cleanup",
        .new_func = livepatch_nop_cleanup,
    },
    {
        .old_name = "kfib",
        .new_func = livepatch_kfib,
    },
    {},
};
static struct klp_object objs[] = {
    {
        .name = "calc",
        .funcs = funcs,
    },
    {},
};
/* clang-format on */

static struct klp_patch patch = {
    .mod = THIS_MODULE,
    .objs = objs,
};

static int livepatch_calc_init(void)
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 1, 0)
    return klp_enable_patch(&patch);
#else
    int ret = klp_register_patch(&patch);
    if (ret)
        return ret;
    ret = klp_enable_patch(&patch);
    if (ret) {
        WARN_ON(klp_unregister_patch(&patch));
        return ret;
    }
    return 0;
#endif
}

static void livepatch_calc_exit(void)
{
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 1, 0)
    WARN_ON(klp_unregister_patch(&patch));
#endif
}

module_init(livepatch_calc_init);
module_exit(livepatch_calc_exit);
MODULE_INFO(livepatch, "Y");
