# database.py
import json

def save_to_database(valid_data_dict):
    print("\n[DB 적재 스크립트 실행]")
    print(json.dumps(valid_data_dict, indent=2, ensure_ascii=False))
    print("-" * 50)
