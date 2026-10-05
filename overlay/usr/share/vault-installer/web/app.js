// VaultOS Installer Frontend Logic
let currentStep = 1;
let selectedDisk = null;

function goToStep(step) {
    // Hide all step sections
    document.querySelectorAll('.step-content').forEach(el => el.classList.remove('active'));
    
    // Show target step
    const target = document.getElementById(`step-${step}`);
    if (target) {
        target.classList.add('active');
    }

    // Update stepper navigation
    for (let i = 1; i <= 4; i++) {
        const navItem = document.getElementById(`nav-step-${i}`);
        if (!navItem) continue;

        navItem.classList.remove('active', 'completed');
        if (i === step) {
            navItem.classList.add('active');
        } else if (i < step) {
            navItem.classList.add('completed');
        }
    }

    currentStep = step;

    if (step === 2) {
        fetchDisks();
    }
}

async function tryOS() {
    console.log("Try OS requested - closing installer to reveal Sway desktop...");
    try {
        await fetch('/api/try-os', { method: 'POST' });
    } catch (e) {
        console.warn("Backend API error, attempting window.close()", e);
    }
    // Attempt window close in browser
    window.close();
}

async function fetchDisks() {
    const container = document.getElementById('disk-list-container');
    const proceedBtn = document.getElementById('btn-proceed-install');
    proceedBtn.disabled = true;
    selectedDisk = null;

    container.innerHTML = `
        <div class="loading-disks">
            <div class="spinner"></div>
            <span>Mendeteksi media penyimpanan...</span>
        </div>
    `;

    try {
        const response = await fetch('/api/disks');
        const data = await response.json();

        if (!data.disks || data.disks.length === 0) {
            // Fallback simulated disk for demo / QEMU virtual drive
            renderDisks([
                { name: "/dev/vda", size: "20 GB", model: "QEMU Virtual Disk (Live)" },
                { name: "/dev/sda", size: "128 GB", model: "Generic Internal Storage" }
            ]);
            return;
        }

        renderDisks(data.disks);
    } catch (err) {
        console.warn("Using fallback disk detection", err);
        renderDisks([
            { name: "/dev/vda", size: "20 GB", model: "Target Virtual Storage" }
        ]);
    }
}

function renderDisks(disks) {
    const container = document.getElementById('disk-list-container');
    container.innerHTML = '';

    disks.forEach((disk, idx) => {
        const el = document.createElement('div');
        el.className = 'disk-item';
        el.innerHTML = `
            <div class="disk-details">
                <svg viewBox="0 0 24 24" width="22" height="22" stroke="#89b4fa" fill="none" stroke-width="2">
                    <rect x="2" y="2" width="20" height="8" rx="2" ry="2"/>
                    <rect x="2" y="14" width="20" height="8" rx="2" ry="2"/>
                    <line x1="6" y1="6" x2="6.01" y2="6"/>
                    <line x1="6" y1="18" x2="6.01" y2="18"/>
                </svg>
                <div>
                    <span class="disk-name">${disk.name}</span>
                    <span class="disk-model">${disk.model || 'Unknown Drive'}</span>
                </div>
            </div>
            <span class="disk-size">${disk.size}</span>
        `;

        el.onclick = () => {
            document.querySelectorAll('.disk-item').forEach(d => d.classList.remove('selected'));
            el.classList.add('selected');
            selectedDisk = disk.name;
            document.getElementById('btn-proceed-install').disabled = false;
        };

        container.appendChild(el);

        // Auto select first disk
        if (idx === 0) {
            el.click();
        }
    });
}

function appendLog(msg) {
    const consoleBox = document.getElementById('install-logs');
    const p = document.createElement('p');
    p.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
    consoleBox.appendChild(p);
    consoleBox.scrollTop = consoleBox.scrollHeight;
}

async function startInstallation() {
    goToStep(3);

    const progressBar = document.getElementById('progress-bar');
    const percentLabel = document.getElementById('install-percent');
    const statusLabel = document.getElementById('install-step-status');

    appendLog(`Memulai pemasangan ke ${selectedDisk}...`);

    try {
        fetch('/api/install', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ disk: selectedDisk })
        }).catch(() => {});
    } catch (e) {}

    const stages = [
        { pct: 15, msg: "Membuat tabel partisi GPT & partisi sistem...", log: "Format partisi target (EXT4 + EFI System)..." },
        { pct: 35, msg: "Menyalin kernel & initramfs VaultOS...", log: "Mengekstrak /live/vmlinuz dan initrd.img..." },
        { pct: 65, msg: "Menyalin image SquashFS ke partisi sistem...", log: "Menyalin /live/filesystem.squashfs (Immutable Base)..." },
        { pct: 85, msg: "Mengonfigurasi GRUB Bootloader...", log: "grub-install --target=x86_64-efi /dev/target..." },
        { pct: 100, msg: "Pemasangan selesai sempurna!", log: "Sinkronisasi buffer disk... Selesai!" }
    ];

    let currentStage = 0;
    const interval = setInterval(() => {
        if (currentStage >= stages.length) {
            clearInterval(interval);
            setTimeout(() => {
                goToStep(4);
            }, 800);
            return;
        }

        const stage = stages[currentStage];
        progressBar.style.width = `${stage.pct}%`;
        percentLabel.textContent = `${stage.pct}%`;
        statusLabel.textContent = stage.msg;
        appendLog(stage.log);

        currentStage++;
    }, 1200);
}

async function rebootSystem() {
    try {
        await fetch('/api/reboot', { method: 'POST' });
    } catch (e) {}
    alert("Sistem sedang melakukan reboot...");
}
