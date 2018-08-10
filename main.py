from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

jenkins_servers = (
    {"type": "ios", "url": "https://ios.domain.com"},
    {"type": "android", "url": "https://android.domain.com"},
    {"type": "docker", "url": "https://docker.domain.com"},
    {"type": "windows", "url": "https://winjenkins.domain.com"}
)

def handler(event, context):
    jenkins_urls = []

    if event['type'] in ['any', 'all']:
        jenkins_urls = [instance['url'] for instance in jenkins_servers]
    elif event['type'] in ['ios', 'android', 'docker', 'windows']:
        jenkins_urls = [instance['url'] for instance in jenkins_servers if instance['type'] == event['type']]

    for url in jenkins_urls:
        for remote in event['remotes']:
            request = Request(f'{url}/git/notifyCommit?url={remote}')
            try:
                response = urlopen(request,timeout=2)
                if response.code == 200:
                    print(f'{url}/git/notifyCommit?url={remote} : Success')
            except (HTTPError, URLError):
                print(f'{url}/git/notifyCommit?url={remote} : Error')

    return
