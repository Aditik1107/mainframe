import urllib.request, re

res = urllib.request.urlopen('http://127.0.0.1:8000/')
html = res.read().decode('utf-8')
print('Status: 200, length:', len(html))

# Check for patent or figure occurrences
patent_matches = re.findall(r'patent|figure|fig\s*\d', html, re.IGNORECASE)
print('Patent/Figure matches in UI:', len(patent_matches))

# Check nav tabs
tabs = re.findall(r'<button onclick="switchTab\([^)]+\)"[^>]*>([^<]+)</button>', html)
print('Nav tabs in order:', [t.strip() for t in tabs])

# Check colors
banned = ['blue', 'indigo', 'cyan', 'purple', 'violet', 'amber', 'yellow', 'orange', 'fuchsia', 'pink', 'teal']
found = {}
for b in banned:
    m = re.findall(rf'\b{b}[-\w]*', html, re.IGNORECASE)
    if m:
        found[b] = set(m)
print('Banned color classes:', found)
