//
//  PaymentReviewViewController.swift
//  GiniPayBusiness
//
//  Created by Nadya Karaban on 30.03.21.
//

import Foundation
import GiniPayApiLib

public final class PaymentReviewViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet var pageControl: UIPageControl!
    @IBOutlet var recipientField: UITextField!
    @IBOutlet var ibanField: UITextField!
    @IBOutlet var amountField: UITextField!
    @IBOutlet var usageField: UITextField!
    @IBOutlet var payButton: UIButton!
    @IBOutlet var paymentInputFieldsErrorLabels: [UILabel]!
    @IBOutlet var usageErrorLabel: UILabel!
    @IBOutlet var amountErrorLabel: UILabel!
    @IBOutlet var ibanErrorLabel: UILabel!
    @IBOutlet var recipientErrorLabel: UILabel!
    @IBOutlet var paymentInputFields: [UITextField]!
    @IBOutlet var bankProviderButtonView: UIView!
    @IBOutlet var inputContainer: UIView!
    @IBOutlet var containerCollectionView: UIView!
    @IBOutlet var paymentInfoStackView: UIStackView!
    @IBOutlet weak var mainContainerView: UIView!
    @IBOutlet var collectionView: UICollectionView!
    
    var model: PaymentReviewModel?
    var paymentProviders: [PaymentProvider] = []
    
    enum TextFieldType: Int {
        case recipientFieldTag = 1
        case ibanFieldTag
        case amountFieldTag
        case usageFieldTag
    }
    
    public static func instantiate(with apiLib: GiniApiLib, document: Document, extractions: [Extraction]) -> PaymentReviewViewController {
        let vc = (UIStoryboard(name: "PaymentReview", bundle: giniPayBusinessBundle())
            .instantiateViewController(withIdentifier: "paymentReviewViewController") as? PaymentReviewViewController)!
        vc.model = PaymentReviewModel(with: apiLib, document: document, extractions: extractions )
        
        return vc
    }

    var giniPayBusinessConfiguration = GiniPayBusinessConfiguration.shared
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        subscribeOnKeyboardNotifications()
        congifureUI()
        setupViewModel()
    }
    
    fileprivate func setupViewModel() {
        model?.checkIfAnyPaymentProviderAvailiable {[weak self] result in
            switch result {
            case let .success(providers):
                DispatchQueue.main.async {
                    self?.paymentProviders.append(contentsOf: providers)
                }
            case .failure(_):
                DispatchQueue.main.async {
                    self?.showError(message: NSLocalizedStringPreferredFormat("ginipaybusiness.errors.no.banking.app.installed",
                                                                              comment: "no supported banking apps installed"))
                }
            }
        }
        model?.onExtractionFetched = { [weak self] () in
            DispatchQueue.main.async {
                self?.fillInInputFields()
            }
        }
        
        model?.updateImagesLoadingStatus = { [weak self] () in
            DispatchQueue.main.async { [weak self] in
                let isLoading = self?.model?.isImagesLoading ?? false
                if isLoading {
                    self?.collectionView.showLoading(style: self?.giniPayBusinessConfiguration.loadingIndicatorStyle, color: self?.giniPayBusinessConfiguration.loadingIndicatorColor, scale: self?.giniPayBusinessConfiguration.loadingIndicatorScale)
                } else {
                    self?.collectionView.stopLoading()
                }
            }
        }
       
        model?.updateLoadingStatus = { [weak self] () in
            DispatchQueue.main.async { [weak self] in
                let isLoading = self?.model?.isLoading ?? false
                if isLoading {
                    self?.view.showLoading(style: self?.giniPayBusinessConfiguration.loadingIndicatorStyle, color: self?.giniPayBusinessConfiguration.loadingIndicatorColor, scale: self?.giniPayBusinessConfiguration.loadingIndicatorScale)
                } else {
                    self?.view.stopLoading()
                }
            }
        }
            
       model?.reloadCollectionViewClosure = { [weak self] () in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
            }
        }
        
        model?.onPreviewImagesFetched = { [weak self] () in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
            }
        }
        
        model?.onErrorHandling = {[weak self] error in
            DispatchQueue.main.async {
                self?.showError(message: NSLocalizedStringPreferredFormat("ginipaybusiness.errors.default",
                                                                         comment: "default error message") )
            }
        }
        
        model?.onNoAppsErrorHandling = {[weak self] error in
            DispatchQueue.main.async {
                self?.showError(message: NSLocalizedStringPreferredFormat("ginipaybusiness.errors.no.banking.app.installed",
                                                                         comment: "no bank apps installed") )
            }
        }
        
        model?.onCreatePaymentRequestErrorHandling = {[weak self] () in
            DispatchQueue.main.async {
                self?.showError(message: NSLocalizedStringPreferredFormat("ginipaybusiness.errors.failed.payment.request.creation",
                                                                      comment: "error for creating payment request"))
            }
        }
        
        model?.fetchImages()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        unsubscribeFromKeyboardNotifications()
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        inputContainer.roundCorners(corners: [.topLeft, .topRight], radius: 12)
    }
    
    // MARK: - congifureUI

    fileprivate func congifureUI() {
        configureScreenBackgroundColor()
        configureCollectionView()
        configurePayButton()
        configurePaymentInputFields()
        configureBankProviderView()
        configurePageControl()
        hideErrorLabels()
        fillInInputFields()
    }

    // MARK: - TODO ConfigureBankProviderView Dynamically configured
    
    fileprivate func configureBankProviderView() {
        bankProviderButtonView.backgroundColor = .white
        bankProviderButtonView.layer.cornerRadius = self.giniPayBusinessConfiguration.paymentInputFieldCornerRadius
        bankProviderButtonView.layer.borderWidth = self.giniPayBusinessConfiguration.paymentInputFieldBorderWidth
        bankProviderButtonView.layer.borderColor = UIColor.from(hex: 0xE6E7ED).cgColor
    }

    fileprivate func configurePayButton() {
        payButton.backgroundColor = UIColor.from(giniColor: giniPayBusinessConfiguration.payButtonBackgroundColor)
        payButton.layer.cornerRadius = giniPayBusinessConfiguration.payButtonCornerRadius
    }
    
    fileprivate func configurePaymentInputFields() {
        for field in paymentInputFields {
            applyDefaultStyle(field)
        }
    }
    
    fileprivate func configureCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    fileprivate func configurePageControl() {
        pageControl.hidesForSinglePage = true
        pageControl.numberOfPages = model?.document.pageCount ?? 1
    }
    
    fileprivate func configureScreenBackgroundColor() {
        let screenBackgroundColor = UIColor.from(giniColor:giniPayBusinessConfiguration.paymentScreenBackgroundColor)
        mainContainerView.backgroundColor = screenBackgroundColor
        containerCollectionView.backgroundColor = screenBackgroundColor
        inputContainer.backgroundColor = UIColor.from(giniColor:giniPayBusinessConfiguration.inputFieldsContainerBackgroundColor)
    }
    
    // MARK: - Input fields configuration

    fileprivate func applyDefaultStyle(_ field: UITextField) {
        field.layer.cornerRadius = self.giniPayBusinessConfiguration.paymentInputFieldCornerRadius
        field.layer.borderWidth = 0.0
        field.backgroundColor = UIColor.from(giniColor: giniPayBusinessConfiguration.paymentInputFieldBackgroundColor)
        field.font = giniPayBusinessConfiguration.paymentInputFieldFont
        field.textColor = UIColor.from(giniColor: giniPayBusinessConfiguration.paymentInputFieldTextColor)
        let placeholderText = inputFieldPlaceholderText(field)
        field.attributedPlaceholder = NSAttributedString(string: placeholderText, attributes: [NSAttributedString.Key.foregroundColor: UIColor.from(giniColor: giniPayBusinessConfiguration.paymentInputFieldPlaceholderTextColor), NSAttributedString.Key.font: giniPayBusinessConfiguration.paymentInputFieldPlaceholderFont])
        field.layer.masksToBounds = true
    }

    fileprivate func applyErrorStyle(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3) {
            textField.layer.cornerRadius = self.giniPayBusinessConfiguration.paymentInputFieldCornerRadius
            textField.backgroundColor = UIColor.from(giniColor: self.giniPayBusinessConfiguration.paymentInputFieldBackgroundColor)
            textField.layer.borderWidth = self.giniPayBusinessConfiguration.paymentInputFieldBorderWidth
            textField.layer.borderColor = self.giniPayBusinessConfiguration.paymentInputFieldErrorStyleColor.cgColor
            textField.layer.masksToBounds = true
        }
    }

    fileprivate func applySelectionStyle(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3) {
            textField.layer.cornerRadius = self.giniPayBusinessConfiguration.paymentInputFieldCornerRadius
            textField.backgroundColor = self.giniPayBusinessConfiguration.paymentInputFieldSelectionBackgroundColor
            textField.layer.borderWidth = self.giniPayBusinessConfiguration.paymentInputFieldBorderWidth
            textField.layer.borderColor = self.giniPayBusinessConfiguration.paymentInputFieldSelectionStyleColor.cgColor
            textField.layer.masksToBounds = true
        }
    }
    
    @objc fileprivate func doneWithAmountInputButtonTapped() {
        let price = Price.init(value: Decimal(string:amountField.text ?? "") ?? 0, currencyCode: "EUR")
        amountField.text = price.string
        view.endEditing(true)
    }

     func addDoneButtonForNumPad(_ textField: UITextField) {
        let toolbarDone = UIToolbar(frame:CGRect(x:0, y:0, width:view.frame.width, height:40))
        
        toolbarDone.sizeToFit()
        let barBtnDone = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.done,
                                              target: self, action: #selector(PaymentReviewViewController.doneWithAmountInputButtonTapped))
        
        toolbarDone.items = [barBtnDone]
        textField.inputAccessoryView = toolbarDone
    }
    
    fileprivate func inputFieldPlaceholderText(_ textField: UITextField) -> String {
        if let fieldIdentifier = TextFieldType(rawValue: textField.tag) {
            switch fieldIdentifier {
            case .recipientFieldTag:
                return NSLocalizedStringPreferredFormat("ginipaybusiness.reviewscreen.recipient.placeholder",
                                                        comment: "placeholder text for recipient input field")
            case .ibanFieldTag:
                return NSLocalizedStringPreferredFormat("ginipaybusiness.reviewscreen.iban.placeholder",
                                                        comment: "placeholder text for iban input field")
            case .amountFieldTag:
                addDoneButtonForNumPad(textField)
                return NSLocalizedStringPreferredFormat("ginipaybusiness.reviewscreen.amount.placeholder",
                                                        comment: "placeholder text for amount input field")
            case .usageFieldTag:
                return NSLocalizedStringPreferredFormat("ginipaybusiness.reviewscreen.usage.placeholder",
                                                        comment: "placeholder text for usage input field")
            }
        }
        return ""
    }
    
    // MARK: - Input fields validation
    
    fileprivate func validateTextField(_ textField: UITextField) {
        if let fieldIdentifier = TextFieldType(rawValue: textField.tag) {
            switch fieldIdentifier {
            case .ibanFieldTag:
                if let ibanText = textField.text, textField.hasText {
                    if IBANValidator().isValid(iban: ibanText) {
                        applyDefaultStyle(textField)
                        hideErrorLabel(textFieldTag: fieldIdentifier)
                    } else {
                        applyErrorStyle(textField)
                        showValidationErrorLabel(textFieldTag: fieldIdentifier)
                    }
                } else {
                    applyErrorStyle(textField)
                    showErrorLabel(textFieldTag: fieldIdentifier)
                }
            case .amountFieldTag:
                
                let price = Price.init(value: Decimal(string:textField.text ?? "") ?? 0, currencyCode: "EUR")
                amountField.text = price.string
                if (Decimal(string: price.stringWithoutSymbol ?? "") ?? 0 > 0) && textField.hasText {
                    applyDefaultStyle(textField)
                    hideErrorLabel(textFieldTag: fieldIdentifier)
                } else {
                    applyErrorStyle(textField)
                    showErrorLabel(textFieldTag: fieldIdentifier)
                }
            case .recipientFieldTag, .usageFieldTag:
                if textField.hasText && !textField.isReallyEmpty {
                    applyDefaultStyle(textField)
                    hideErrorLabel(textFieldTag: fieldIdentifier)
                } else {
                    applyErrorStyle(textField)
                    showErrorLabel(textFieldTag: fieldIdentifier)
                }
            }
        }
    }

    fileprivate func validateAllInputFields() {
        for textField in paymentInputFields {
            validateTextField(textField)
        }
    }
    
    fileprivate func hideErrorLabels() {
        for errorLabel in paymentInputFieldsErrorLabels {
                errorLabel.isHidden = true
        }
    }
    
    fileprivate func fillInInputFields() {
        recipientField.text = model?.extractions.first(where: {$0.name == "paymentRecipient"})?.value
        ibanField.text = model?.extractions.first(where: {$0.name == "iban"})?.value
        usageField.text = model?.extractions.first(where: {$0.name == "paymentPurpose"})?.value
        let amountString = model?.extractions.first(where: {$0.name == "amountToPay"})?.value

        let price = Price.init(extractionString: amountString ?? "0.00:EUR")
        amountField.text = price?.string
    }

    fileprivate func showErrorLabel(textFieldTag: TextFieldType) {
        var errorLabel = UILabel()
        var errorMessage = ""
        switch textFieldTag {
        case .recipientFieldTag:
            errorLabel = recipientErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginipaybusiness.errors.failed.recipient.non.empty.check",
                                                            comment: " recipient failed non empty check")
        case .ibanFieldTag:
            errorLabel = ibanErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginipaybusiness.errors.failed.iban.non.empty.check",
                                                            comment: "iban failed non empty check")
        case .amountFieldTag:
            errorLabel = amountErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginipaybusiness.errors.failed.amount.non.empty.check",
                                                            comment: "amount failed non empty check")
        case .usageFieldTag:
            errorLabel = usageErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginipaybusiness.errors.failed.purpose.non.empty.check",
                                                            comment: "purpose failed non empty check")
        }
        if errorLabel.isHidden {
            errorLabel.isHidden = false
            errorLabel.textColor = giniPayBusinessConfiguration.paymentInputFieldErrorStyleColor
            errorLabel.text = errorMessage
        }
    }
    
    fileprivate func showValidationErrorLabel(textFieldTag: TextFieldType) {
        var errorLabel = UILabel()
        var errorMessage = NSLocalizedStringPreferredFormat("ginipaybusiness.errors.failed.default.textfield.validation.check",
                                                            comment: "the field failed non empty check")
        switch textFieldTag {
        case .recipientFieldTag:
            errorLabel = recipientErrorLabel
        case .ibanFieldTag:
            errorLabel = ibanErrorLabel
            errorMessage = NSLocalizedStringPreferredFormat("ginipaybusiness.errors.failed.iban.validation.check",
                                                            comment: "iban failed validation check")
        case .amountFieldTag:
            errorLabel = amountErrorLabel
        case .usageFieldTag:
            errorLabel = usageErrorLabel
        }
        if errorLabel.isHidden {
            errorLabel.isHidden = false
            errorLabel.textColor = giniPayBusinessConfiguration.paymentInputFieldErrorStyleColor
            errorLabel.text = errorMessage
        }
    }

    fileprivate func hideErrorLabel(textFieldTag: TextFieldType) {
        var errorLabel = UILabel()
        switch textFieldTag {
        case .recipientFieldTag:
            errorLabel = recipientErrorLabel
        case .ibanFieldTag:
            errorLabel = ibanErrorLabel
        case .amountFieldTag:
            errorLabel = amountErrorLabel
        case .usageFieldTag:
            errorLabel = usageErrorLabel
        }
        if !errorLabel.isHidden {
            errorLabel.isHidden = true
        }
    }
    
    // MARK: - IBAction
    
    @IBAction func payButtonClicked(_ sender: Any) {
        validateAllInputFields()
        
        //check if no errors labels are shown
        if (paymentInputFieldsErrorLabels.allSatisfy { $0.isHidden }) {
            let amountText = amountField.text ?? ""
            if let selectedPaymentProvider = paymentProviders.first {
                let paymentInfo = PaymentInfo(recipient: recipientField.text ?? "", iban: ibanField.text ?? "", bic: "", amount: amountText, purpose: usageField.text ?? "", paymentProviderScheme: selectedPaymentProvider.appSchemeIOS, paymentProviderId: selectedPaymentProvider.id)
                
                view.showLoading()
                
                model?.createPaymentRequest(paymentInfo: paymentInfo)
            }
        }
    }
    
    // MARK: - Keyboard handling
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            /**
             If keyboard size is not available for some reason, dont do anything
             */
            return
        }
        /**
         Moves the root view up by the distance of keyboard height  taking in account safeAreaInsets.bottom
         */
        if #available(iOS 11.0, *) {
            view.frame.origin.y = 0 - keyboardSize.height + view.safeAreaInsets.bottom
        } else {
            view.frame.origin.y = 0 - keyboardSize.height
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        /**
         Moves back the root view origin to zero
         */
        view.frame.origin.y = 0
    }

    func subscribeOnKeyboardNotifications() {
        /**
         Calls the 'keyboardWillShow' function when the view controller receive the notification that a keyboard is going to be shown
         */
        NotificationCenter.default.addObserver(self, selector: #selector(PaymentReviewViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)

        /**
         Calls the 'keyboardWillHide' function when the view controlelr receive notification that keyboard is going to be hidden
         */
        NotificationCenter.default.addObserver(self, selector: #selector(PaymentReviewViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    fileprivate func unsubscribeFromKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - UITextFieldDelegate

extension PaymentReviewViewController: UITextFieldDelegate {
    /**
     Dissmiss the keyboard when return key pressed
     */
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        validateTextField(textField)
        return true
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        validateTextField(textField)
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        applySelectionStyle(textField)
        if let fieldIdentifier = TextFieldType(rawValue: textField.tag) {
            hideErrorLabel(textFieldTag: fieldIdentifier)
        }
    }
}
// MARK: - UICollectionViewDelegate, UICollectionViewDataSource

extension PaymentReviewViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 1 }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        model?.numberOfCells ?? 1
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "pageCellIdentifier", for: indexPath) as! PageCollectionViewCell
        cell.pageImageView.frame = CGRect(x: 0, y: 0, width: collectionView.frame.width, height: collectionView.frame.height)
        
        let cellModel = model?.getCellViewModel(at: indexPath)
        cell.pageImageView.display(image: cellModel?.preview ?? UIImage())
        return cell
    }
    // MARK: - UICollectionViewDelegateFlowLayout
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = collectionView.frame.height
        let width = collectionView.frame.width
        return CGSize(width: width, height: height)
    }

    // MARK: - For Display the page number in page controll of collection view Cell

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(scrollView.contentOffset.x) / Int(scrollView.frame.width)
    }
    
}

extension PaymentReviewViewController {
    func showError(_ title: String? = nil, message: String) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        let OKAction = UIAlertAction(title: NSLocalizedStringPreferredFormat("ginipaybusiness.alert.ok.title",
                                                                             comment: "ok title for action"), style: .default, handler: nil)
        alertController.addAction(OKAction)
        present(alertController, animated: true, completion: nil)
    }
}