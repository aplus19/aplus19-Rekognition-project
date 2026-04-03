

const CONFIG = {
  API_URL: "https://bzq4ra12d4.execute-api.us-east-1.amazonaws.com",
  INPUT_BUCKET: "project2-rekognition-image-inputs"
};

const fileInput = document.getElementById("fileInput");
const dropZone = document.getElementById("dropZone");
const previewSec = document.getElementById("preview-section");
const previewImg = document.getElementById("preview");
const analyzeBtn = document.getElementById("analyzeBtn");
const statusDiv = document.getElementById("status");
const resultsDiv = document.getElementById("results");

let selectedFile = null;

fileInput.addEventListener("change", function(e) {
  handleFile(e.target.files[0]);
});

dropZone.addEventListener("dragover", function(e) {
  e.preventDefault();
  dropZone.style.borderColor = "#58a6ff";
});

dropZone.addEventListener("dragleave", function() {
  dropZone.style.borderColor = "#30363d";
});

dropZone.addEventListener("drop", function(e) {
  e.preventDefault();
  dropZone.style.borderColor = "#30363d";
  handleFile(e.dataTransfer.files[0]);
});

function handleFile(file) {
  if (!file) return;
  if (!["image/jpeg", "image/png"].includes(file.type)) {
    alert("Please upload a JPEG or PNG file.");
    return;
  }
  if (file.size > 5 * 1024 * 1024) {
    alert("File must be under 5MB.");
    return;
  }
  selectedFile = file;
  previewImg.src = URL.createObjectURL(file);
  previewSec.classList.remove("hidden");
  resultsDiv.classList.add("hidden");
  statusDiv.classList.add("hidden");
  document.getElementById("results-placeholder").classList.remove("hidden");
}

analyzeBtn.addEventListener("click", async function() {
  if (!selectedFile) return;

  analyzeBtn.disabled = true;
  analyzeBtn.textContent = "Analyzing...";
  showStatus("Uploading and analyzing your image...");

  try {
    const base64 = await toBase64(selectedFile);
    showStatus("Running Rekognition analysis...");
    const res = await fetch(CONFIG.API_URL + "/analyze", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "analyze_base64",
        filename: selectedFile.name,
        image_data: base64,
        content_type: selectedFile.type
      })
    });

    if (!res.ok) throw new Error("Analysis failed");
    const data = await res.json();
    renderResults(data);

  } catch (err) {
    showStatus("Error: " + err.message);
  } finally {
    analyzeBtn.disabled = false;
    analyzeBtn.textContent = "Analyze Image";
  }
});

function toBase64(file) {
  return new Promise(function(resolve, reject) {
    const reader = new FileReader();
    reader.onload = function() {
      resolve(reader.result.split(",")[1]);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function renderResults(data) {
  let html = "";

  if (data.labels && data.labels.length) {
    html += '<div class="section"><h2>🏷️ Labels (' + data.labels.length + ')</h2><div class="tags">';
    data.labels.forEach(function(l) {
      html += '<span class="tag">' + l.name + ' <strong>' + l.confidence + '%</strong></span>';
    });
    html += "</div></div>";
  }

  if (data.faces && data.faces.length) {
    html += '<div class="section"><h2>👤 Faces (' + data.faces.length + ')</h2>';
    data.faces.forEach(function(f) {
      const emotion = f.emotions && f.emotions[0];
      html += '<div class="face-card">';
      html += '<div><div class="label">Face</div><div class="value">#' + f.face_index + '</div></div>';
      html += '<div><div class="label">Age</div><div class="value">' + f.age_range.low + '-' + f.age_range.high + '</div></div>';
      html += '<div><div class="label">Gender</div><div class="value">' + f.gender.value + '</div></div>';
      html += '<div><div class="label">Emotion</div><div class="value">' + (emotion ? emotion.type : "N/A") + '</div></div>';
      html += '<div><div class="label">Smile</div><div class="value">' + (f.smile.value ? "Yes" : "No") + '</div></div>';
      html += '<div><div class="label">Glasses</div><div class="value">' + (f.eyeglasses.value ? "Yes" : "No") + '</div></div>';
      html += "</div>";
    });
    html += "</div>";
  }

  const lines = data.text ? data.text.filter(function(t) { return t.type === "LINE"; }) : [];
  if (lines.length) {
    html += '<div class="section"><h2>📝 Text (' + lines.length + ')</h2><div class="tags">';
    lines.forEach(function(t) {
      html += '<span class="tag">' + t.detected_text + ' <strong>' + t.confidence + '%</strong></span>';
    });
    html += "</div></div>";
  }

  if (!html) {
    html = '<div class="section"><p style="color:#8b949e">No detections found. Try a clearer image.</p></div>';
  }

  resultsDiv.innerHTML = html;
  resultsDiv.classList.remove("hidden");
  statusDiv.classList.add("hidden");
  document.getElementById("results-placeholder").classList.add("hidden");
  saveToHistory(selectedFile ? selectedFile.name : "image", data);
}

function showStatus(msg) {
  statusDiv.textContent = msg;
  statusDiv.classList.remove("hidden");
}

function showTab(tabName) {
  document.querySelectorAll(".tab-content").forEach(function(t) {
    t.classList.remove("active");
  });
  document.querySelectorAll(".nav-link").forEach(function(l) {
    l.classList.remove("active");
  });
  document.getElementById("tab-" + tabName).classList.add("active");
  event.target.classList.add("active");
  if (tabName === "history") loadHistory();
}

const analysisHistory = JSON.parse(localStorage.getItem("rekognition_history") || "[]");

function saveToHistory(filename, result) {
  analysisHistory.unshift({
    filename: filename,
    timestamp: new Date().toLocaleString(),
    labelCount: result.labels ? result.labels.length : 0,
    faceCount: result.faces ? result.faces.length : 0,
    textCount: result.text ? result.text.filter(function(t) { return t.type === "LINE"; }).length : 0,
    result: result
  });
  if (analysisHistory.length > 20) analysisHistory.pop();
  localStorage.setItem("rekognition_history", JSON.stringify(analysisHistory));
}

function loadHistory() {
  const container = document.getElementById("history-list");
  if (!analysisHistory.length) {
    container.innerHTML = '<div class="empty-state"><div class="placeholder-icon">📂</div><p>No analyses yet!</p></div>';
    return;
  }
  container.innerHTML = analysisHistory.map(function(item, i) {
    return '<div class="history-item" onclick="showHistoryResult(' + i + ')">' +
      '<div><div class="history-name">' + item.filename + '</div>' +
      '<div class="history-meta">' + item.timestamp + ' · ' +
      item.labelCount + ' labels · ' + item.faceCount + ' faces · ' + item.textCount + ' text</div></div>' +
      '<span class="history-badge">View</span></div>';
  }).join("");
}

function showHistoryResult(index) {
  showTab("analyze");
  document.querySelector('[onclick="showTab(\'analyze\')"]').classList.add("active");
  renderResults(analysisHistory[index].result);
  document.getElementById("results-placeholder").classList.add("hidden");
}

