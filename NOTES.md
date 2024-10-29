### Default run

```sh
sbatch job.sh
```

### With branch

```sh
sbatch job.sh '/main'
```

### Interactive

```sh
srun --cpus-per-task=96 --mem=0 --time=12:00:00 --partition=fast --pty ~/nyx/job.sh '/main'
```

