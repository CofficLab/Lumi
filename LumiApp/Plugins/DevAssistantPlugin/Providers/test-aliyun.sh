#!/bin/bash

# 阿里云 Coding Plan API 测试脚本
# 用于测试 Anthropic 兼容接口的连通性

# 配置信息
API_KEY="sk-sp-601d118d986c475b9ecb2d8e3d243ef0"
BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic/v1"
MODEL="qwen3.5-plus"

echo "========================================"
echo "阿里云 Coding Plan API 测试"
echo "========================================"
echo "API URL: $BASE_URL"
echo "模型：$MODEL"
echo "API Key: ${API_KEY:0:10}..."
echo "========================================"
echo ""

# 测试 1: 简单对话测试
echo "【测试 1】简单对话测试..."
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{
    \"model\": \"$MODEL\",
    \"max_tokens\": 100,
    \"system\": \"你是一个助手。\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"你好，请回复'测试成功'\"
      }
    ]
  }")

# 分离响应体和状态码
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP 状态码：$HTTP_CODE"
echo ""
echo "响应内容:"
echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

# 判断测试结果
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 测试成功！API 响应正常"

    # 尝试提取返回内容
    CONTENT=$(echo "$RESPONSE_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',[{}])[0].get('text',''))" 2>/dev/null)
    if [ -n "$CONTENT" ]; then
        echo ""
        echo "AI 回复：$CONTENT"
    fi
elif [ "$HTTP_CODE" = "401" ]; then
    echo "❌ 测试失败！认证错误 (401)"
    echo "请检查 API Key 是否正确"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "❌ 测试失败！端点不存在 (404)"
    echo "请检查 API URL 是否正确"
else
    echo "❌ 测试失败！HTTP 错误：$HTTP_CODE"
fi

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
