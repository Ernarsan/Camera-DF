import urllib.request, re
req = urllib.request.Request('https://github.com/Ernarsan/Camera-DF/actions', headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        html = response.read().decode('utf-8')
        m = re.findall(r'<svg.*?aria-label="(.*?)".*?data-test-selector="workflow-run-status".*?>', html, re.DOTALL)
        if m:
            print('STATUS:', m)
        else:
            print('No match')
except Exception as e:
    print('Error:', e)
