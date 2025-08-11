import sys,os
import json
import requests
import datetime
import time
import pytz
from optparse import OptionParser
import warnings
from urllib3.exceptions import InsecureRequestWarning
warnings.simplefilter("ignore", InsecureRequestWarning)




def get_pagination_obj():

    obj = {
        "paginated_tables":[
            {"table_id":"glycosylation_reported_with_glycan","offset":1,"limit":20,"sort":"start_pos","order":"asc"},
            {"table_id":"glycosylation_reported","offset":1,"limit":20,"sort":"start_pos","order":"asc"},
            {"table_id":"glycosylation_predicted","offset":1,"limit":20,"sort":"start_pos","order":"asc"},
          {"table_id":"glycosylation_automatic_literature_mining","offset":1,"limit":20,"sort":"start_pos","order":"asc"},
            {"table_id":"phosphorylation","offset":1,"limit":20,"sort":"start_pos","order":"asc"},
            {"table_id":"snv_disease","offset":1,"limit":20,"sort":"start_pos","order":"asc"},
            {"table_id":"snv_non_disease","offset":1,"limit":20,"sort":"start_pos","order":"asc"},
            {"table_id":"publication","offset":1,"limit":200,"sort":"date","order":"desc"}
        ],
        "filtering":{
            "table_id":"glycosylation_reported_with_glycan",
            "filters": [
                    {"id": "by_mass", "operator": "OR", "selected": [ "0k_1k" ]}
            ]
        }
    }
    return obj



def get_req_obj_list():

    obj_list = [
        {"id":"O14686-1", "size":"14M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"Q8WZ42-1", "size":"14M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"O14497-1", "size":"11M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"P68431-1", "size":"11M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"P42336-1", "size":"11M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"Q8WXI7-1", "size":"11M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"Q8NEZ4-1", "size":"11M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"P60484-1", "size":"9.9M", "type":"protein", "id_field":"uniprot_canonical_ac"}
        ,{"id":"Q99102-1", "size":"9.7M", "type":"protein", "id_field":"uniprot_canonical_ac"}
    ]


    return obj_list




def main():

    usage = "\n%prog  [options]"
    parser = OptionParser(usage,version="%prog version___")
    parser.add_option("-s","--server",action="store",dest="server",help="dev/tst/beta/prd")

    (options,args) = parser.parse_args()
    for key in ([options.server]):
        if not (key):
            parser.print_help()
            sys.exit(0)

    server = options.server

    url_map = {
        "dev":"https://api.dev.glygen.org/misc/get_object/",
        "tst":"https://api.tst.glygen.org/misc/get_object/",
        "beta":"https://beta-api.glygen.org/misc/get_object/",
        "prd":"https://api.glygen.org/misc/get_object/"
    }
    api_url = url_map[server]
    ts_format = "%Y-%m-%d %H:%M:%S %Z%z"

    req_obj_list = get_req_obj_list()


    row = ["api_overhead",  "network_overhead","response_size(Bytes)", "object_type", "object_id", "mode"]
    print (", ".join(row))

    for mode in ["filesystem", "mongodb", "mongodb-pagination"]:
        for req_obj in req_obj_list:
            req_obj["mode"] = mode
            if mode == "mongodb-pagination":
                req_obj["pagination"] = get_pagination_obj()
            start_ts = datetime.datetime.now(pytz.timezone('US/Eastern'))
            res = requests.post(api_url, json=req_obj, verify=False)
            end_ts = datetime.datetime.now(pytz.timezone('US/Eastern'))
            if res.status_code != 200:
                print ("Error! status_code=%s" % (res.status_code))
                continue
            size = len(res.content)
            network_overhead = str(end_ts - start_ts)
            start_ts_f = start_ts.strftime(ts_format)
            end_ts_f = end_ts.strftime(ts_format)
            res_obj =  json.loads(res.content)
            api_overhead = res_obj["api_overhead"]["elapsed"]
            row = [api_overhead,  network_overhead,str(size), req_obj["type"], req_obj["id"], mode] 
            print (", ".join(row))
            time.sleep(2) 


    return






if __name__ == '__main__':
    main()





