### About this performance test
This test tries to measure the amount of network time taken for a JSON response. It uses the largest 10 protein JSON objects which are retrieved using three different modes. When the "filesystem" mode is used, the objects are retrieved from a local disk (local to the GlyGen production server instance). On the other hand, when the modes "mongodb" or "mongodb-pagination" are used, the objects are retrieved from MongoDB using the same function used in the protein/detail API.


### Downloading and run python test script
```
$ wget https://raw.githubusercontent.com/glygener/io-benchmarker/refs/heads/main/network-test.py
$ pip install requests
$ pip install pytz
$ python3 network-test.py -s prd
```

### Example result rows
```
api_overhead, network_overhead, response_size(Bytes), object_type, object_id, mode
0:00:00.133007, 0:00:00.603896, 7046218, protein, O14686-1, filesystem
0:00:00.121230, 0:00:00.337708, 7355279, protein, Q8WZ42-1, filesystem
0:00:00.102755, 0:00:00.301703, 5558897, protein, O14497-1, filesystem
0:00:00.097398, 0:00:00.298153, 5614271, protein, P68431-1, filesystem
0:00:00.090217, 0:00:00.288278, 5674754, protein, P42336-1, filesystem
0:00:00.085981, 0:00:00.271904, 5575423, protein, Q8WXI7-1, filesystem
0:00:00.097048, 0:00:00.283619, 5395669, protein, Q8NEZ4-1, filesystem
0:00:00.084703, 0:00:00.255399, 5049650, protein, P60484-1, filesystem
0:00:00.076633, 0:00:00.258258, 5237365, protein, Q99102-1, filesystem
0:00:02.472486, 0:00:02.688515, 6380256, protein, O14686-1, mongodb
0:00:04.157630, 0:00:04.369046, 6728765, protein, Q8WZ42-1, mongodb
0:00:00.665235, 0:00:00.847324, 5029499, protein, O14497-1, mongodb
0:00:00.697292, 0:00:00.881178, 5124318, protein, P68431-1, mongodb
0:00:02.736325, 0:00:02.920565, 5193166, protein, P42336-1, mongodb
0:00:02.605701, 0:00:02.804206, 5059821, protein, Q8WXI7-1, mongodb
0:00:02.831905, 0:00:03.010498, 4899757, protein, Q8NEZ4-1, mongodb
0:00:00.631902, 0:00:00.813114, 4571881, protein, P60484-1, mongodb
0:00:05.471754, 0:00:05.656027, 4820488, protein, Q99102-1, mongodb
0:00:01.854308, 0:00:01.921286, 890850, protein, O14686-1, mongodb-pagination
0:00:06.082577, 0:00:06.180578, 1486086, protein, Q8WZ42-1, mongodb-pagination
0:00:01.803260, 0:00:01.877444, 577895, protein, O14497-1, mongodb-pagination
0:00:01.450222, 0:00:01.524662, 694628, protein, P68431-1, mongodb-pagination
0:00:02.390049, 0:00:02.484372, 1256194, protein, P42336-1, mongodb-pagination
0:00:02.662817, 0:00:02.725618, 572475, protein, Q8WXI7-1, mongodb-pagination
0:00:01.399475, 0:00:01.464750, 941108, protein, Q8NEZ4-1, mongodb-pagination
0:00:00.467310, 0:00:00.537318, 889896, protein, P60484-1, mongodb-pagination
0:00:01.423883, 0:00:01.479787, 726703, protein, Q99102-1, mongodb-pagination
```
