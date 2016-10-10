Script d'installation
---------------------
# Ping tout les serveurs

```
ansible -i inventory all -m ping
```
# Provisionner (installer)

## Provisionner un serveur
```
ansible-playbook -i inventory --limit localhost playbook.yml
```

## Tester sans provisionner le serveur
```
ansible-playbook -i inventory --limit localhost playbook.yml -C
```
/!\ Ne marche pas toujours jusqu'au bout. Car certaines tâche son dépendantes les unes des autres

## Provisionner le serveur de pré-production et production

```
ansible-playbook -i inventory --limit server-1,server-2 playbook.yml
```