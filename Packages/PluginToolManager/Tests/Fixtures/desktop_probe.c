#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdio.h>

// Only looks up ports. It never sends events, captures a screen, or launches apps.
int main(void) {
    const char *names[] = {
        "com.apple.windowserver.active",
        "com.apple.coreservices.appleevents",
        "com.apple.coreservices.launchservicesd"
    };
    int connected = 0;
    for (int i = 0; i < 3; ++i) {
        mach_port_t port = MACH_PORT_NULL;
        kern_return_t result = bootstrap_look_up(bootstrap_port, names[i], &port);
        printf("%s:%d\n", names[i], result);
        if (result == KERN_SUCCESS) {
            connected++;
            mach_port_deallocate(mach_task_self(), port);
        }
    }
    return connected == 0 ? 0 : 1;
}
