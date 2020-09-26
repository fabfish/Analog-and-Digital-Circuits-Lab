/*void C�˻�View::OnDraw(CDC *pDC*);
{
    C�˻�Doc *pDoc = GetDocument();
    ASSERT_VALID(pDoc);
    if (!pDoc)
        return;
        // TODO: �ڴ˴�Ϊ����������ӻ��ƴ���
*/ 
#include "math.h"
#define Pi 3.14159

    {
        //C�˻�Doc *pDoc = GetDocument();
        ASSERT_VALID(pDoc);
        //���ƻ���
        CPen cpen, pen;
        cpen.CreatePen(PS_SOLID, 4, RGB(0, 0, 0));
        pen.CreatePen(PS_SOLID, 2, RGB(255, 0, 0));
        pDC->SelectObject(&cpen);

        //ָ��ԭ��
        pDC->SetViewportOrg(300, 300);
        pDC->SetTextColor(RGB(255, 0, 0));
        double nTemp int n
            //���ƺ�����
            CString sPiText[] = {"-1/2��", "1/2��", "��", "3/2��", "2��", "5/2��", "3��", "7/2��", "4��", "9/2��", "5��"};
        for (int n = -1, nTemp = 0; nTemp <= 660; n++, nTemp += 60)
        {
            pDC->LineTo(60 * n, 0); //�������
            pDC->LineTo(60 * n, -5);
            pDC->MoveTo(60 * n, 0);
            pDC->TextOut(60 * n - sPiText[n + 1].GetLength() * 3, 16, sPiText[n + 1]);
        }
        pDC->MoveTo(0, 0);
        CString sTemp;
        //����������
        for (n = -4, nTemp = 0; nTemp <= 180; n++, nTemp = 60 * n)
        {
            pDC->LineTo(0, 60 * n);
            pDC->LineTo(5, 60 * n);
            pDC->MoveTo(0, 60 * n);
            sTemp.Format("%d", -n);
            pDC->TextOut(10, 60 * n, sTemp);
        }
        double y, radian;
        pDC->SelectObject(&pen);

        //�����������
        for (int x = -60; x < 600; x++)
        {
            //����=X����/���߿��*�Ƕ�*��
            //Y����=���*���߿��*sin(����)
            radian = x / ((double)60 * 2) * Pi;
            y = sin(radian) * 2 * 60;
            pDC->MoveTo((int)x, -(int)y);
            pDC->LineTo((int)x, -(int)y);
        }
        cpen.DeleteObject();
        pen.DeleteObject();
    }
//}
