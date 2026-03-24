# test_pipeline.py
import time
import json
import random
import config
from pipeline import PreprocessingPipeline

def simulate_real_world_data(is_anomaly=False):
    data = {}
    for field in config.DATA_FIELDS:
        # 정상 데이터 진동 폭 (50 ± 10 정도 안에서 가우스 분포로 진동)
        value = random.gauss(50.0, 5.0)
        
        if is_anomaly and random.random() < 0.15: # 15% 정도 확률로 어떤 필드가 튐
            # 완전 이상한 값으로 오인식 되는 상황
            if random.random() < 0.5:
                # 자리수가 하나 더 붙거나, 완전히 큰 값
                value += random.uniform(200.0, 800.0) 
            else:
                # 마이너스 값 등
                value -= random.uniform(100.0, 300.0)
                
        data[field] = round(value, 2)
        
    return json.dumps(data)

if __name__ == "__main__":
    app_pipeline = PreprocessingPipeline()
    
    print("시스템 학습 모드 (정상 데이터 10개 연속 주입)")
    print("초기 히스토리 배열(Moving Avg, Z-Score)을 채우고, 기준(mean, std)을 잡습니다.\n")
    for _ in range(10):
        # 처음 10개는 절대 튀지 않는 데이터
        app_pipeline.process_incoming_data(simulate_real_world_data(is_anomaly=False))
        
    print("\n========================================================")
    print("실시간 유입 이상치 검사 시작 (약 15%의 더미 노이즈 포함)")
    print("========================================================\n")
    for step in range(1, 4):
        print(f"Step {step}: 외부 센서/OCR 데이터 인입")
        mock_payload = simulate_real_world_data(is_anomaly=True)
        
        # 어떤 변수가 맛이 갔는지(노이즈 발생했는지) 확인용 출력
        raw = json.loads(mock_payload)
        outliers_in_raw = {k: v for k, v in raw.items() if v < 20 or v > 80}
        print(f"     ㄴ [원시데이터 확인용] 주입된 비정상 값들: {outliers_in_raw}")
        
        # 실제 파이프라인 처리
        app_pipeline.process_incoming_data(mock_payload)
        time.sleep(1)
        
    print("\n테스트 종료됨.")
