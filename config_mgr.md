Alteon L4 Switch Config Manager

기능 
1. config file을 읽고 코멘트와 필요없는 부분을 제거하고 실제 config 만 추출하여 임시파일로 저장한다.
2. 컨피그만 저장한 임시파일의 확장자는 .cfg로 저장한다.
3. comment는 /* 로 시작하고 그 줄이 끝날때까지 무시한다.
4. 실제 컨피그의 내용의 시작은 "/c/sys/access"로 시작한다.
5. 실제 컨피그의 내용의 끝은 "/" 로 시작한다.

