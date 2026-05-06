## Running the Project with Docker

Follow these steps to set up the environment, build the source, and execute the ray tracer.

### 1. Environment Setup
Before starting the container, allow the Docker container to access your local X server (required for GUI/display features):

```bash
xhost +local:docker
```

### 2. Start the Container
Spin up the environment using Docker Compose:

```bash
docker compose up
```

---

### 3. Build Instructions
Once inside the container, navigate to the `/app` directory and choose a build configuration:

*   **Release Mode** (Optimized for performance):
    ```bash
    cmake -B build/Release -DCMAKE_BUILD_TYPE=Release -S /app && cmake --build build/Release
    ```
*   **Debug Mode** (Includes debug symbols):
    ```bash
    cmake -B build/Debug -DCMAKE_BUILD_TYPE=Debug -S /app && cmake --build build/Debug
    ```

---

### 4. Execution
Run the compiled binary and redirect the output to a `.ppm` image file:

| Configuration | Execution Command |
| :--- | :--- |
| **Release** | `./build/Release/GPUAccRayTracer > output.ppm` |
| **Debug** | `./build/Debug/GPUAccRayTracer > output.ppm` |
```
    
