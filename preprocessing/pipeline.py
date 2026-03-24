# pipeline.py
import json
import config
from filters.moving_average import MovingAverageFilter
from filters.z_score import ZScoreFilter
from database import save_to_database

class PreprocessingPipeline:
    def __init__(self):
        # 체인(Chain) 형태로 필터를 등록
        self.filters = [
            ZScoreFilter(
                data_fields=config.DATA_FIELDS, 
                window_size=config.Z_WINDOW_SIZE, 
                threshold=config.Z_SCORE_THRESHOLD
            ),
            MovingAverageFilter(
                data_fields=config.DATA_FIELDS, 
                window_size=config.MA_WINDOW_SIZE, 
                max_deviation=config.MA_MAX_DEVIATION
            )
        ]

    def absolute_check(self, field, value):
        # 절대 범위 초과 필터
        if not (config.ABSOLUTE_MIN <= value <= config.ABSOLUTE_MAX):
            print(f"  └ [AbsRange 🚫]  {field} 터무니 없는 값 삭제됨: ({value})")
            return False
        return True

    def process_incoming_data(self, raw_json_data):
        """이 함수를 통해 스트리밍/폴링 된 JSON 문자열이 유입됩니다."""
        try:
            data = json.loads(raw_json_data)
        except json.JSONDecodeError:
            print("[오류] 올바른 형태의 JSON이 아닙니다.")
            return

        filtered_data = {}
        
        # 14개의 사전 약속된 센서 변수들을 순회하면서 필터링
        for field in config.DATA_FIELDS:
            if field in data:
                current_value = float(data[field]) # 계산을 위해 강제 형변환
                
                # 1. 절대 범위 우선 검사
                if not self.absolute_check(field, current_value):
                    continue
                    
                # 2. 고도화된 이상치 알고리즘 체인 검사
                passed_all_filters = True
                for f in self.filters:
                    if not f.process(field, current_value):
                        passed_all_filters = False
                        break # 하나라도 실패시(오인식 감지시) 이상치로 보고 바로 버림
                
                # 다 통과한 정상 데이터만 DB 적재를 위해 모음 처리
                if passed_all_filters:
                    
                    filtered_data[field] = current_value
            else:
                pass # JSON에 해당 key가 없는 경우 무시
                
        # 전처리 결과 DB 전송
        if filtered_data:
            save_to_database(filtered_data)
        else:
            print("\n[알림] 이번 사이클의 모든 값이 필터링되어 저장할 것이 없습니다.")
            print("-" * 50)
