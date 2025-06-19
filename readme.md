<div align="center"> 

# GENSYN AUTOMATED SCRIPT </div>

### All The Dependencies,Packages Will be automitacally installed by one click

#### Put The Below Command In Terminal:
```
 sudo apt-get update && sudo apt-get install -y bash && bash <(curl -sSL https://raw.githubusercontent.com/arookiecoder-ip/Gensyn_Automated_Script/refs/heads/main/script.sh) 
```
#### Create A Screen And Start Cloudflare Session by: 

```
screen -S cloudflare 
```
#### Then Start The Session:
```
cloudflared tunnel --url http://localhost:3000
```
>Open The Link<br>

> Then Detach The Screen : `CTRL+A` and then `CTRL+D`

#### Now Create Another Screen For Gensyn:
````
screen -S gensyn
````

* Navigate to `rl-swarm`:
````
cd rl-swarm
````
* Create And Activate A Virtual Environment:
````
python3 -m venv .venv
source .venv/bin/activate
````

* Start The Program:
````
./run_and_alert.sh
````