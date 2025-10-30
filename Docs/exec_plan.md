### Your Step-by-Step Execution Plan

#### Phase A: The Setup - "Mise en Place" (Getting Everything Ready)

**Objective:** Prepare your development environment and team workflow before writing a single line of application code. **Do not skip this phase.**

1.  **Initialize Version Control (Git):**
    *   Create a new repository on GitHub, GitLab, or your platform of choice.
    *   One person initializes the project locally: `git init`, creates the top-level directory structure from **Prompt 0.1**, and makes the first commit: `git commit -m "Initial project structure"`.
    *   Push this to the remote repository. All other team members clone this repository.

2.  **Establish the "LLM Contract":**
    *   Save the **System Prompt** you were given into a text file (`system_prompt.txt`) in the project root. This ensures everyone uses the same instructions for the LLM.
    *   Execute **Prompt 0.0** to create the `INSTRUCTIONS.md` file. Commit and push it. Your team should read and agree to follow these rules.

3.  **Build the Kubernetes Cluster (The Foundation):**
    *   **This is your most important initial task.** As a team, follow a guide to set up a multi-node **k3s** cluster.
    *   **Designate Roles:** One laptop is the `master` (control-plane), the other two are `workers`.
    *   **Network:** Ensure all three laptops are on the same WiFi network and can `ping` each other. You may need to adjust firewall settings.
    *   **Verify:** Once set up, run `kubectl get nodes -o wide`. You should see all three nodes listed and in the `Ready` state. This confirms your cluster is functional.
    *   **Document:** As you do this, fill out the `docs/setup-guide.md`. This will be invaluable if you need to rebuild it.

4.  **Install Essential Tooling:**
    *   Every team member must install:
        *   `kubectl` (Kubernetes command-line tool).
        *   `Docker Desktop` (for building images).
        *   `Lens` or `k9s` (highly recommended GUI/TUI tools for easier cluster management).
        *   Code editors with the necessary plugins for Go, Python, Node.js, and ProtoBufs.

#### Phase B: The Execution Loop - "Cooking the Dish"

**Objective:** Systematically execute the prompts phase by phase to build the application.

1.  **Appoint a "Lead Prompter" for the Phase:** This person is responsible for feeding the prompts to the LLM.

2.  **Follow the Cycle for Each Prompt:**
    *   **a) Prompt:** The Lead Prompter copies and pastes the *entire* prompt into the LLM.
    *   **b) Generate & Review (Peer Review):** The LLM will generate the code/config. **Do not blindly copy-paste it.** The entire team should review the output. Ask these questions:
        *   Does it directly address the prompt?
        *   Does it follow the rules in `INSTRUCTIONS.md`? (e.g., non-root user, JSON logging).
        *   Is the logic sound? Do you understand what the code is doing?
    *   **c) Integrate:** The Lead Prompter carefully places the generated code into the correct files in the local repository.
    *   **d) Commit:** Commit the changes with a descriptive message referencing the prompt number. Example: `git commit -m "feat(bidding-logic): Implement Prompt 2.5 gRPC client integration"`.
    *   **e) Push:** Push the commit to the remote repository.

3.  **The Phase-End Verification:**
    *   After the last prompt of a phase (e.g., after Prompt 1.5), stop.
    *   Execute the steps in the verification plan document for that phase (e.g., `docs/testing/phase-1-verification.md`).
    *   The whole team should be present for this, observing the logs and outputs.
    *   **This is a critical "gate".** Do not proceed to the next phase until the current one is fully working and verified. If it's not working, move to the Debugging Loop.

#### Phase C: The Debugging Loop - "Fixing the Recipe"

**Objective:** Handle the inevitable bugs and errors from the LLM or your setup.

1.  **Isolate the Problem:** Don't just say "it's broken." Use your tools:
    *   `kubectl get pods -n helios`: Are all pods `Running`? Any in `CrashLoopBackOff`?
    *   `kubectl describe pod <pod-name> -n helios`: Look at the "Events" section at the bottom. This often tells you why a pod won't start (e.g., `ImagePullBackOff`, `ConfigMapNotFound`).
    *   `kubectl logs <pod-name> -n helios`: This is your best friend. Look for error messages in the application logs.

2.  **Formulate a Corrective Prompt:** Once you identify the error, create a specific, targeted prompt for the LLM.
    *   **Bad Prompt:** "It's not working, fix it."
    *   **Good Prompt:** "The code you generated in Prompt 2.2 for `services/user-profile-service/src/server.ts` is crashing. The logs show a `RedisConnectionError: AUTH command requires password`. Please modify the Redis client initialization to include the password, which will be provided by a `REDIS_PASSWORD` environment variable."

3.  **Test the Fix:** Apply the corrected code, rebuild the Docker image, update the deployment (`kubectl rollout restart deployment/...`), and re-run the verification steps for that part.
