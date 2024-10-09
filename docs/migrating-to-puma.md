Multi-Process Cloud Controller Migration Guide

Until now, the CF API has been limited to scaling horizontally.  The web server technology that Cloud Controller is built on top of, Thin, can only utilize a single process to serve traffic.

With the introduction of multi-process support for Cloud Controller, operators can now configure their foundations to use fewer API instances to support the same amount of traffic.


## How Scaling currently works in Single-Process Mode

Using single-process mode (powered by Thin), Cloud Controller cannot utilize more than a single process per VM. This is because Thin cannot use multiple processes to serve traffic on the same port at the same time. 

In single-process mode, Cloud Controller sees little benefit by being deployed to a multiple-core machine, as Cloud Controller can only utilize a single core. 

By default, Cloud Controller in single-process mode is configured to use 20 threads, meaning a single Cloud Controller process can comfortably handle 20 concurrent API requests before response time is slowed due to requests being stuck in the queue.

Once a foundation’s API group is at its limit, the only way to support more HTTP requests is to add more API vms.

Each single-process API instance has 2 colocated job queue workers (called ‘local workers’) to handle package and droplet uploads to the blobstore. It’s generally sufficient for both the API process and the 2 local workers to run on a single core.


## How Scaling works in Multi-Process Mode

Using multi-process mode (powered by Puma), Cloud Controller can utilize multiple processes (called ‘workers’) to serve traffic on the same port.

Cloud Controller only benefits from multiple workers if there is a CPU core available to each worker.

By default each worker is configured to use 10 threads, meaning each worker can process up to 10 concurrent requests. We don’t recommend configuring more than 20 threads per worker.

More workers on an individual instance results in a higher memory utilization.

**It’s important to note that a single Puma worker with 20 threads is generally not as resilient as a single Thin instance.** However, a cluster of Puma workers is more resilient than a group of individual Thin instances, as if one worker is stalled or crashes, queued requests can be routed to the other workers.

It’s recommended that each API instance has twice as many local job workers as there are API workers. This can vary depending on foundation load. See [Scaling Local Workers](https://docs.cloudfoundry.org/running/managing-cf/scaling-cloud-controller.html#cloud_controller_worker_local) for more details.


## Migrating from Single-process to Multi-process API instances

When upgrading, it’s important to ensure the API instance group can support the same number of concurrent requests. Typically a Single-process API instance will support 20 threads. To ensure parity when migrating to Multi-process API instances, ensure that the total number of workers multiplied by the number of threads per worker is equal to (or greater than) the number of Single-process instances multiplied by the number of threads (usually 20).


### Examples

Here are a few possible configurations that would result in similar number of threads:

|                                         |                  |                  |                  |                  |
| --------------------------------------- | ---------------- | ---------------- | ---------------- | ---------------- |
|                                         | Profile 1 (Thin) | Profile 2 (Puma) | Profile 3 (Puma) | Profile 4 (Puma) |
| **VM type**                             | 1 CPU            | 2 CPU            | 4 CPU            | 8 CPU            |
| **# instances**                         | 20               | 10               | 8                | 4                |
| **# API workers**                       | 1 (Thin)         | 2                | 4                | 7                |
| **# threads/worker**                    | 20               | 20               | 13               | 15               |
| **Total concurrent requests supported** | 400              | 400              | 416              | 420              |

**Profile 1 (Thin):** A typical API instance group today. The only recommended way to increase the maximum number of concurrent requests is to scale the number of instances.

**Profile 2 (Puma):** With only 2 cores, this profile is not taking full advantage of multi-process support. Since each worker is already configured to use 20 threads, this profile can only be scaled by increasing the number of machine cores or total instances. 

**Profile 3 (Puma):** This profile can be scaled by increasing the number of cores, total instances, or threads.

**Profile 4 (Puma):** This profile only has 7 API workers for 8 CPU cores. This can be helpful, but not strictly necessary, to ensure colocated processes have enough CPU resources to run. This profile can be scaled by increasing the number of workers to 8 as well as number of cores, total instances, or threads. This profile will be the most demanding in terms of memory footprint.


### Fine-tuning your foundation

When upgrading your foundation to Multi-Process mode, it’s recommended to initially over-allocate resources and fine-tune from there. For example, you might follow any/all of the following strategies:

- Provision one or more extra API instances than the above concurrent requests calculation would require

- Keep the thread count per worker less than 20

- Increase memory for your API instances by a factor of how many workers each instance will have in multi-process mode.

Once upgraded, watch the following metrics to understand if your provisioned resources can be reduced or need to be scaled up:

- `cc.requests.outstanding.gauge`

  - If this value is at or consistently near the total number of available Puma threads on the VM, that may indicate you need to scale your instance group

- `system.cpu.user`

  - Should stay below 0.85 total utilization.

- `cc.vitals.cpu_load_avg`

  - Should stay below the total number of CPU cores.


## Configuring Your Foundation

1. To enable Multi-Process mode, set the [cc.experimental.puma property](https://github.com/cloudfoundry/capi-release/blob/develop/jobs/cloud_controller_ng/spec#L1249) to `true`

2. Set the [cc.puma.workers](https://github.com/cloudfoundry/capi-release/blob/develop/jobs/cloud_controller_ng/spec#L1256C3-L1256C18) to the number of CPU cores your machines have.

3. Set [cc.puma.max\_threads](https://github.com/cloudfoundry/capi-release/blob/develop/jobs/cloud_controller_ng/spec#L1260C3-L1260C22) to the desired number of threads. We recommend at least 10.

4. Set [cc.puma.max\_db\_connections\_per\_process](https://github.com/cloudfoundry/capi-release/blob/develop/jobs/cloud_controller_ng/spec#L1264C3-L1264C41) to at least the same number of values as `cc.puma.threads`
