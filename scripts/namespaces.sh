pkill -f srsue
pkill -f srsenb
pkill -f srsepc
pkill -f gnuradio
pkill -f broker

sudo fuser -k 2000/tcp 2001/tcp 2>/dev/null
sudo fuser -k 2100/tcp 2101/tcp 2>/dev/null
sudo fuser -k 2200/tcp 2201/tcp 2>/dev/null
sudo fuser -k 2300/tcp 2301/tcp 2>/dev/null
sudo fuser -k 2400/tcp 2401/tcp 2>/dev/null

sudo ip netns del ue1 2>/dev/null
sudo ip netns del ue2 2>/dev/null
sudo ip netns del ue3 2>/dev/null
sudo ip netns del ue4 2>/dev/null

sudo ip netns add ue1
sudo ip netns add ue2
sudo ip netns add ue3
sudo ip netns add ue4

sudo ip netns exec ue1 nc -zu 172.16.0.1 9999
sudo ip netns exec ue2 nc -zu 172.16.0.1 9999
sudo ip netns exec ue3 nc -zu 172.16.0.1 9999
